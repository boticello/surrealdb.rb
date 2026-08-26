# frozen_string_literal: true

require 'weakref'

module SurrealDB
  module Connections
    # Embedded transport for SurrealDB via FFI to libsurrealdb_c.
    #
    # Supports mem://, memory://, surrealkv://, and file:// URL schemes. Uses
    # the shared CBOR request encoder, but calls directly into the C library
    # instead of going over the network.
    #
    # Requires `require "surrealdb/embedded"` before use.
    #
    # ## Thread Safety
    #
    # The underlying C library handles its own threading via a Tokio runtime,
    # and all FFI calls use `blocking: true` to release the GVL. A connection
    # is owned by the thread that first calls #connect; cross-thread use raises
    # ThreadSafetyError. Create one Client per thread.
    class Embedded < Base
      TIMEOUT_RANGE = (0..255)

      # Owns native resources independently from the connection object so its
      # finalizer can release an abandoned connection without retaining it.
      class NativeResources
        attr_reader :stream_ptr

        def initialize(rpc_ptr)
          @rpc_ptr = rpc_ptr
          @stream_ptr = nil
          @reader_thread = nil
          @stream_closed = false
          @released = false
          @mutex = Mutex.new
          @reader_registered = ConditionVariable.new
        end

        def register_stream(stream_ptr)
          @mutex.synchronize { @stream_ptr = stream_ptr }
        end

        def register_reader(reader_thread)
          @mutex.synchronize do
            @reader_thread = reader_thread
            @reader_registered.broadcast
          end
        end

        def wait_for_reader_registration
          @mutex.synchronize { @reader_registered.wait(@mutex) until @reader_thread }
        end

        def close_stream
          stream_ptr = @mutex.synchronize do
            next if @stream_closed

            @stream_closed = true
            @stream_ptr
          end
          Native.sr_rpc_stream_close(stream_ptr) if stream_ptr
        end

        def shutdown
          close_stream
          reader_thread = @mutex.synchronize { @reader_thread }
          reader_thread.join if reader_thread && !reader_thread.equal?(Thread.current)
          release
        end

        def finalizer
          proc { release_after_garbage_collection }
        end

        private

        def release
          resources = @mutex.synchronize do
            next if @released

            @released = true
            stream_ptr = @stream_ptr
            rpc_ptr = @rpc_ptr
            @stream_ptr = nil
            @rpc_ptr = nil
            @reader_thread = nil
            [stream_ptr, rpc_ptr]
          end
          return [nil, nil] unless resources

          stream_ptr, rpc_ptr = resources
          Native.sr_rpc_stream_free(stream_ptr) if stream_ptr
          return [nil, nil] unless rpc_ptr

          err_ptr = FFI::MemoryPointer.new(:pointer)
          ret = Native.sr_surreal_rpc_close(rpc_ptr, err_ptr)
          [ret, err_ptr]
        ensure
          Native.sr_surreal_rpc_free(rpc_ptr) if rpc_ptr
        end

        def release_after_garbage_collection
          ret, err_ptr = shutdown
          return unless ret&.negative?

          error_ptr = err_ptr.read_pointer
          Native.sr_free_string(error_ptr) unless error_ptr.null?
        rescue StandardError
          # Finalizers cannot safely report errors and cleanup is already best-effort.
        end
      end

      # Reads native notifications without capturing an Embedded instance.
      class NotificationReader
        def self.start(resources, connection_ref)
          Thread.new(resources, connection_ref) do |reader_resources, reader_connection_ref|
            Thread.current.report_on_exception = false
            reader_resources.wait_for_reader_registration
            run(reader_resources, reader_connection_ref)
          end
        end

        def self.run(resources, connection_ref)
          loop { break unless continue_reading?(resources, connection_ref) }
        rescue StandardError => e
          with_connection(connection_ref) do |connection|
            connection.send(:log, :warn, "Embedded notification reader terminated: #{e.class}: #{e.message}")
          end
        end

        def self.continue_reading?(resources, connection_ref)
          res_ptr = FFI::MemoryPointer.new(:pointer)
          length = Native.sr_rpc_stream_next(resources.stream_ptr, res_ptr)
          return false if length == Native::SR_CLOSED

          if length.negative?
            with_connection(connection_ref) do |connection|
              connection.send(:log, :warn, "Embedded notification stream failed with code #{length}")
            end
            return false
          end

          return true if with_connection(connection_ref) do |connection|
            response = connection.send(:read_and_free_response, res_ptr, length)
            connection.send(:dispatch_notification, response)
          end

          Native.sr_free_byte_arr(res_ptr.read_pointer, length)
          resources.close_stream
          false
        end

        def self.with_connection(connection_ref)
          connection = connection_ref.__getobj__
          yield connection
          true
        rescue WeakRef::RefError
          false
        end

        private_class_method :continue_reading?, :with_connection
      end

      def initialize(url, **options)
        super
        default_timeout = options.fetch(:timeout, SurrealDB.configuration.timeout)
        @query_timeout = validate_timeout(:query_timeout, options.fetch(:query_timeout, default_timeout))
        @transaction_timeout = validate_timeout(
          :transaction_timeout,
          options.fetch(:transaction_timeout, default_timeout)
        )
        validate_strict_option(options.fetch(:strict, false))
        @native_url = normalize_url(url)
        @rpc_ptr = nil
        @resources = nil
        @reader_thread = nil
        @live_handlers = {}
        @live_mutex = Mutex.new
        @owner_thread = nil
        @owner_mutex = Mutex.new
      end

      def connect
        claim_owner_thread!
        raise ConnectionError, 'already connected' if @rpc_ptr

        begin
          err_ptr = FFI::MemoryPointer.new(:pointer)
          surreal_ptr = FFI::MemoryPointer.new(:pointer)

          opts = Native::SrOption.new
          opts[:strict] = false
          opts[:query_timeout] = @query_timeout
          opts[:transaction_timeout] = @transaction_timeout

          ret = Native.sr_surreal_rpc_new(err_ptr, surreal_ptr, @native_url, opts)
          check_error!(ret, err_ptr)

          @rpc_ptr = surreal_ptr.read_pointer
          @resources = NativeResources.new(@rpc_ptr)
          ObjectSpace.define_finalizer(self, @resources.finalizer)
          @connected = true
          start_notification_reader
          log(:debug, "Embedded connection opened: #{@url}")
        rescue StandardError
          @connected = false
          release_rpc_context
          raise
        end
      end

      def close
        verify_owner_thread!
        return unless @resources

        @connected = false
        release_rpc_context
        log(:debug, 'Embedded connection closed')
      end

      def send_request(method, params = [])
        verify_owner_thread!
        raise ConnectionError, 'not connected' unless @connected

        wire_params, session_id, transaction_id = rpc_request_context(method, params)
        _id, encoded = @rpc.encode_request(
          method,
          wire_params,
          session: session_id,
          transaction: transaction_id
        )

        err_ptr = FFI::MemoryPointer.new(:pointer)
        res_ptr = FFI::MemoryPointer.new(:pointer)

        ret = Native.sr_surreal_rpc_execute(
          @rpc_ptr, err_ptr, res_ptr,
          encoded, encoded.bytesize
        )
        check_error!(ret, err_ptr)

        result = extract_response(method, res_ptr, ret)
        result = update_rpc_context_after_success(method, session_id, result)
        @live_mutex.synchronize { @live_handlers.clear } if method == Protocol::Methods::DETACH
        result
      end

      def supports_live_queries?
        true
      end

      def supports_queries?
        true
      end

      def supports_sessions?
        true
      end

      # Registers a live query notification handler.
      # @param live_query_id [String]
      # @param handler [Proc, Queue]
      def on_notification(live_query_id, handler)
        verify_owner_thread!
        @live_mutex.synchronize { @live_handlers[live_query_id] = handler }
      end

      # Removes a live query notification handler.
      # @param live_query_id [String]
      def remove_notification_handler(live_query_id)
        verify_owner_thread!
        @live_mutex.synchronize { @live_handlers.delete(live_query_id) }
      end

      private

      def extract_response(method, res_ptr, length)
        decoded = read_and_free_response(res_ptr, length)
        Protocol::Response.extract_result(decoded)
      rescue ServerError => e
        reconcile_rpc_context_error(method, e)
        raise
      end

      def claim_owner_thread!
        @owner_mutex.synchronize { @owner_thread ||= Thread.current }
        verify_owner_thread!
      end

      def verify_owner_thread!
        return unless @owner_thread
        return if Thread.current.equal?(@owner_thread)

        raise ThreadSafetyError,
              'embedded connections must be used from the thread that called #connect; create one Client per thread'
      end

      def validate_timeout(name, value)
        return value if value.is_a?(Integer) && TIMEOUT_RANGE.cover?(value)

        raise ArgumentError, "#{name} must be an Integer from 0 to 255 seconds (0 disables the timeout)"
      end

      def validate_strict_option(strict)
        return if strict == false
        raise UnsupportedError, 'strict mode is not supported by the embedded C RPC API' if strict == true

        raise ArgumentError, 'strict must be true or false'
      end

      def normalize_url(url)
        scheme, location = url.split('://', 2)
        raise ArgumentError, 'embedded URL must include ://' unless location

        normalized_scheme = scheme.downcase
        native_scheme = case normalized_scheme
                        when 'file' then 'surrealkv'
                        when 'memory' then 'mem'
                        else normalized_scheme
                        end
        "#{native_scheme}://#{location}"
      end

      def read_and_free_response(res_ptr, length)
        raw_ptr = res_ptr.read_pointer
        begin
          bytes = raw_ptr.read_bytes(length)
          @rpc.decode_response(bytes)
        ensure
          Native.sr_free_byte_arr(raw_ptr, length)
        end
      end

      def start_notification_reader
        err_ptr = FFI::MemoryPointer.new(:pointer)
        stream_ptr = FFI::MemoryPointer.new(:pointer)
        ret = Native.sr_surreal_rpc_notifications(@rpc_ptr, err_ptr, stream_ptr)
        check_error!(ret, err_ptr)

        @resources.register_stream(stream_ptr.read_pointer)
        reader_thread = NotificationReader.start(@resources, WeakRef.new(self))
        @resources.register_reader(reader_thread)
        @reader_thread = reader_thread
      end

      def dispatch_notification(response)
        result = Protocol::Response.extract_result(response)
        return unless result.is_a?(Hash)

        live_id = result['id']&.to_s
        action = result['action']
        return unless live_id && action

        handler = @live_mutex.synchronize { @live_handlers[live_id] }
        deliver_notification(handler, result)
      rescue StandardError => e
        log(:warn, "Dropped malformed embedded notification: #{e.class}: #{e.message}")
      end

      def deliver_notification(handler, result)
        case handler
        when Queue then handler.push(result)
        when Proc  then handler.call(result)
        end
      end

      def check_error!(ret, err_ptr)
        return if ret >= 0

        err_str_ptr = err_ptr.read_pointer
        message = if err_str_ptr.null?
                    "unknown error (code #{ret})"
                  else
                    begin
                      err_str_ptr.read_string
                    ensure
                      Native.sr_free_string(err_str_ptr)
                    end
                  end

        if ret == Native::SR_FATAL
          @connected = false
          raise ConnectionError, "fatal error (connection poisoned): #{message}"
        end

        raise ServerError, message
      end

      def release_rpc_context
        resources = @resources
        @resources = nil
        @rpc_ptr = nil
        ObjectSpace.undefine_finalizer(self)
        begin
          ret, err_ptr = resources.shutdown if resources
          check_error!(ret, err_ptr) if ret
        ensure
          reset_rpc_context!
          @live_mutex.synchronize { @live_handlers.clear }
        end
      end

      def log(level, message)
        SurrealDB.configuration.logger&.send(level, message)
      end
    end
  end
end
