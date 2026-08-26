# frozen_string_literal: true

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
        @stream_ptr = nil
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
        return unless @rpc_ptr

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

        @stream_ptr = stream_ptr.read_pointer
        @reader_thread = Thread.new do
          Thread.current.report_on_exception = false
          notification_loop
        end
      end

      def notification_loop
        loop do
          res_ptr = FFI::MemoryPointer.new(:pointer)
          length = Native.sr_rpc_stream_next(@stream_ptr, res_ptr)
          break if length == Native::SR_CLOSED

          if length.negative?
            log(:warn, "Embedded notification stream failed with code #{length}")
            break
          end

          dispatch_notification(read_and_free_response(res_ptr, length))
        end
      rescue StandardError => e
        log(:warn, "Embedded notification reader terminated: #{e.class}: #{e.message}")
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

      def shutdown_notification_reader
        stream_ptr = @stream_ptr
        return unless stream_ptr

        Native.sr_rpc_stream_close(stream_ptr)
        @reader_thread&.join
        Native.sr_rpc_stream_free(stream_ptr)
      ensure
        @stream_ptr = nil
        @reader_thread = nil
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
        rpc_ptr = @rpc_ptr
        @rpc_ptr = nil
        begin
          shutdown_notification_reader
          if rpc_ptr
            err_ptr = FFI::MemoryPointer.new(:pointer)
            check_error!(Native.sr_surreal_rpc_close(rpc_ptr, err_ptr), err_ptr)
          end
        ensure
          Native.sr_surreal_rpc_free(rpc_ptr) if rpc_ptr
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
