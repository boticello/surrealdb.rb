# frozen_string_literal: true

require "socket"
require "openssl"
require "uri"
require "websocket/driver"

module SurrealDB
  module Connections
    # WebSocket transport for SurrealDB RPC.
    #
    # Uses websocket-driver for protocol handling and a background reader thread
    # to route responses by request ID. Supports live query notifications.
    class WebSocket < Base
      # @return [Integer] response timeout in seconds
      attr_reader :timeout

      def initialize(url, **options)
        super
        @timeout = options.fetch(:timeout, SurrealDB.configuration.timeout)
        @pending = {}
        @live_handlers = {}
        @mutex = Mutex.new
        @socket = nil
        @driver = nil
        @reader_thread = nil
      end

      def connect
        uri = URI.parse(@url)
        @socket = open_socket(uri)
        ws_url = build_ws_url(uri)

        @driver = ::WebSocket::Driver.client(SocketWrapper.new(@socket, ws_url))
        setup_driver_handlers

        @driver.start

        # Wait for the WebSocket handshake to complete
        wait_for_open

        @connected = true
        start_reader
      end

      def close
        return unless @connected

        @connected = false
        @driver&.close
        shutdown_reader
        @socket&.close
        @socket = nil

        @mutex.synchronize do
          @pending.each_value { |q| q.push(:closed) }
          @pending.clear
        end
      end

      def send_request(method, params = [])
        raise ConnectionError, "not connected" unless @connected

        id, encoded = @rpc.encode_request(method, params)
        queue = Queue.new

        @mutex.synchronize { @pending[id] = queue }

        begin
          @driver.binary(encoded)
          result = dequeue_with_timeout(queue)
          response = @rpc.decode_response(result)
          Protocol::Response.extract_result(response)
        ensure
          @mutex.synchronize { @pending.delete(id) }
        end
      end

      def supports_live_queries?
        true
      end

      # Registers a handler for live query notifications.
      # @param live_query_id [String]
      # @param handler [Proc, Queue] receives notification hashes
      def on_notification(live_query_id, handler)
        @mutex.synchronize { @live_handlers[live_query_id] = handler }
      end

      # Removes a live query notification handler.
      # @param live_query_id [String]
      def remove_notification_handler(live_query_id)
        @mutex.synchronize { @live_handlers.delete(live_query_id) }
      end

      private

      def open_socket(uri)
        tcp = TCPSocket.new(uri.host, uri.port || default_port(uri.scheme))
        return tcp unless uri.scheme == "wss"

        ctx = OpenSSL::SSL::SSLContext.new
        ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
        ctx.cert_store = OpenSSL::X509::Store.new.tap(&:set_default_paths)
        ssl = OpenSSL::SSL::SSLSocket.new(tcp, ctx)
        ssl.hostname = uri.host
        ssl.connect
        ssl
      end

      def default_port(scheme)
        scheme == "wss" ? 443 : 80
      end

      def build_ws_url(uri)
        path = uri.path.empty? ? "/rpc" : uri.path
        port_str = uri.port ? ":#{uri.port}" : ""
        "#{uri.scheme}://#{uri.host}#{port_str}#{path}"
      end

      def setup_driver_handlers
        @open_queue = Queue.new
        @open_error = nil

        @driver.on :open do
          @open_queue.push(:open)
        end

        @driver.on :error do |event|
          @open_error = event.message
          @open_queue.push(:error)
        end

        @driver.on :message do |event|
          handle_message(event.data)
        end

        @driver.on :close do
          @connected = false
          @mutex.synchronize do
            @pending.each_value { |q| q.push(:closed) }
            @pending.clear
          end
        end
      end

      def wait_for_open
        result = nil
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout

        loop do
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise ConnectionError, "WebSocket handshake timed out" if remaining <= 0

          result = try_pop(@open_queue)
          break if result

          data = read_socket
          raise ConnectionError, "connection closed during handshake" if data.nil? || data.empty?

          @driver.parse(data)
        end

        case result
        when :open then return
        when :error then raise ConnectionError, "WebSocket handshake failed: #{@open_error}"
        else raise ConnectionError, "connection closed during handshake"
        end
      end

      def start_reader
        @reader_thread = Thread.new do
          Thread.current.report_on_exception = false
          reader_loop
        end
      end

      def reader_loop
        while @connected
          data = read_socket
          if data.nil? || data.empty?
            @connected = false
            break
          end
          @driver.parse(data)
        end
      rescue IOError, Errno::ECONNRESET, OpenSSL::SSL::SSLError
        @connected = false
      end

      def read_socket
        @socket.readpartial(16_384)
      rescue EOFError
        nil
      end

      def handle_message(data)
        bytes = data.is_a?(Array) ? data.pack("C*") : data.b

        raw = ::CBOR.decode(bytes)
        id = raw["id"]

        if id
          @mutex.synchronize do
            queue = @pending[id]
            queue&.push(bytes)
          end
        else
          dispatch_notification(raw, bytes)
        end
      rescue StandardError
        # Malformed messages are silently dropped to keep the reader alive
      end

      def dispatch_notification(raw, _bytes)
        result = raw["result"] || raw
        live_id = result["id"] if result.is_a?(Hash)
        return unless live_id

        handler = @mutex.synchronize { @live_handlers[live_id] }
        return unless handler

        resolved = CBOR::Decoder.resolve(result)
        case handler
        when Queue then handler.push(resolved)
        when Proc  then handler.call(resolved)
        end
      end

      def shutdown_reader
        @reader_thread&.join(2)
        @reader_thread&.kill if @reader_thread&.alive?
        @reader_thread = nil
      end

      def dequeue_with_timeout(queue)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + @timeout

        loop do
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise TimeoutError, "request timed out after #{@timeout}s" if remaining <= 0

          result = try_pop(queue)
          if result
            raise ConnectionError, "connection closed" if result == :closed

            return result
          end

          sleep 0.01
        end
      end

      # Non-blocking pop that returns nil instead of raising on empty queue.
      def try_pop(queue)
        queue.pop(true)
      rescue ThreadError
        nil
      end

      # Minimal wrapper that gives websocket-driver the interface it expects:
      # #url for the request URL, and #write for sending bytes.
      class SocketWrapper
        attr_reader :url

        def initialize(socket, url)
          @socket = socket
          @url = url
        end

        def write(data)
          @socket.write(data)
        end
      end
    end
  end
end
