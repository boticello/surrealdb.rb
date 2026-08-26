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

    # sr_option_t is passed by value to sr_surreal_rpc_new.
    class SrOption < FFI::Struct
      layout :strict, :bool,
             :query_timeout, :uint8,
             :transaction_timeout, :uint8
    end

    # Return code constants from surrealdb.h
    SR_NONE   = 0   # success / no more items
    SR_CLOSED = -1  # notification stream closed
    SR_ERROR  = -2  # recoverable error
    SR_FATAL  = -3  # connection poisoned, must not reuse

    # Connection lifecycle
    attach_function :sr_surreal_rpc_new,
                    [:pointer, :pointer, :string, SrOption.by_value], :int,
                    blocking: true
    attach_function :sr_surreal_rpc_close,
                    %i[pointer pointer], :int,
                    blocking: true
    attach_function :sr_surreal_rpc_free,
                    [:pointer], :void,
                    blocking: true

    # CBOR request/response
    attach_function :sr_surreal_rpc_execute,
                    %i[pointer pointer pointer pointer int], :int,
                    blocking: true

    # Live-query notification stream
    attach_function :sr_surreal_rpc_notifications,
                    %i[pointer pointer pointer], :int,
                    blocking: true
    attach_function :sr_rpc_stream_next,
                    %i[pointer pointer], :int,
                    blocking: true
    attach_function :sr_rpc_stream_close,
                    [:pointer], :void,
                    blocking: true
    attach_function :sr_rpc_stream_free,
                    [:pointer], :void,
                    blocking: true

    # Memory cleanup
    attach_function :sr_free_string, [:pointer], :void, blocking: true
    attach_function :sr_free_byte_arr, %i[pointer int], :void, blocking: true
  end
end
