# frozen_string_literal: true

require 'ffi'

module SurrealDB
  module Native
    extend FFI::Library

    begin
      ffi_lib Platform.library_path
    rescue LoadError => e
      raise LoadError, Platform.load_error_message(e)
    end

    # FFI struct mapping the C `sr_option_t` passed to {sr_surreal_rpc_new}.
    #
    # @attr strict [Boolean] strict mode (unsupported; always false)
    # @attr query_timeout [Integer] query timeout in seconds (0-255; 0 = disabled)
    # @attr transaction_timeout [Integer] transaction timeout in seconds (0-255; 0 = disabled)
    class SrOption < FFI::Struct
      layout :strict, :bool,
             :query_timeout, :uint8,
             :transaction_timeout, :uint8
    end

    # @return [Integer] success / no more items
    SR_NONE   = 0 # success / no more items
    # @return [Integer] notification stream closed
    SR_CLOSED = -1 # notification stream closed
    # @return [Integer] recoverable error; check err_ptr for details
    SR_ERROR  = -2 # recoverable error
    # @return [Integer] fatal error; connection poisoned, must not reuse
    SR_FATAL  = -3 # connection poisoned, must not reuse

    # Opens a new embedded SurrealDB RPC connection.
    # @param err_ptr [FFI::Pointer] receives error string pointer
    # @param surreal_ptr [FFI::Pointer] receives Surreal instance pointer
    # @param url [String] engine URL (e.g. "mem://", "surrealkv://path")
    # @param opts [SrOption] connection options struct (passed by value)
    # @return [Integer] return code (>= 0 success, < 0 error)
    attach_function :sr_surreal_rpc_new,
                    [:pointer, :pointer, :string, SrOption.by_value], :int,
                    blocking: true

    # Closes an RPC connection and releases its resources.
    # @param rpc_ptr [FFI::Pointer] Surreal instance pointer
    # @param err_ptr [FFI::Pointer] receives error string pointer
    # @return [Integer] return code
    attach_function :sr_surreal_rpc_close,
                    %i[pointer pointer], :int,
                    blocking: true

    # Frees a Surreal instance pointer (call after close).
    # @param rpc_ptr [FFI::Pointer]
    attach_function :sr_surreal_rpc_free,
                    [:pointer], :void,
                    blocking: true

    # Executes a CBOR-encoded RPC request and returns a CBOR response.
    # @param rpc_ptr [FFI::Pointer] Surreal instance
    # @param err_ptr [FFI::Pointer] receives error string pointer
    # @param res_ptr [FFI::Pointer] receives response byte array pointer
    # @param data [FFI::Pointer] CBOR request bytes
    # @param len [Integer] request byte length
    # @return [Integer] response byte length (>= 0), or error code (< 0)
    attach_function :sr_surreal_rpc_execute,
                    %i[pointer pointer pointer pointer int], :int,
                    blocking: true

    # Opens a live-query notification stream for the connection.
    # @param rpc_ptr [FFI::Pointer] Surreal instance
    # @param err_ptr [FFI::Pointer] receives error string pointer
    # @param stream_ptr [FFI::Pointer] receives stream pointer
    # @return [Integer] return code
    attach_function :sr_surreal_rpc_notifications,
                    %i[pointer pointer pointer], :int,
                    blocking: true

    # Blocks until the next notification is available on the stream.
    # @param stream_ptr [FFI::Pointer] notification stream
    # @param res_ptr [FFI::Pointer] receives response byte array pointer
    # @return [Integer] response length (>= 0), {SR_CLOSED} (-1), or error (< 0)
    attach_function :sr_rpc_stream_next,
                    %i[pointer pointer], :int,
                    blocking: true

    # Closes the notification stream (unblocks a waiting {sr_rpc_stream_next}).
    # @param stream_ptr [FFI::Pointer]
    attach_function :sr_rpc_stream_close,
                    [:pointer], :void,
                    blocking: true

    # Frees the notification stream pointer.
    # @param stream_ptr [FFI::Pointer]
    attach_function :sr_rpc_stream_free,
                    [:pointer], :void,
                    blocking: true

    # Frees a C string allocated by the library.
    # @param ptr [FFI::Pointer]
    attach_function :sr_free_string, [:pointer], :void, blocking: true

    # Frees a byte array allocated by the library.
    # @param ptr [FFI::Pointer]
    # @param len [Integer] array length
    attach_function :sr_free_byte_arr, %i[pointer int], :void, blocking: true
  end
end
