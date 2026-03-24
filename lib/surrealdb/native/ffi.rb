# frozen_string_literal: true

require "ffi"

module SurrealDB
  module Native
    extend FFI::Library

    ffi_lib Platform.library_path

    # sr_option_t is passed by value to sr_surreal_rpc_new.
    class SrOption < FFI::Struct
      layout :strict, :bool,
             :query_timeout, :uint8,
             :transaction_timeout, :uint8
    end

    # Return code constants from surrealdb.h
    SR_NONE   =  0  # success / no more items
    SR_CLOSED = -1  # stream closed
    SR_ERROR  = -2  # recoverable error
    SR_FATAL  = -3  # connection poisoned, must not reuse

    # Connection lifecycle
    attach_function :sr_surreal_rpc_new,
                    [:pointer, :pointer, :string, SrOption.by_value], :int,
                    blocking: true
    attach_function :sr_surreal_rpc_free,
                    [:pointer], :void

    # CBOR request/response
    attach_function :sr_surreal_rpc_execute,
                    [:pointer, :pointer, :pointer, :pointer, :int], :int,
                    blocking: true

    # Live query notification stream
    attach_function :sr_surreal_rpc_notifications,
                    [:pointer, :pointer, :pointer], :int,
                    blocking: true
    attach_function :sr_rpc_stream_next,
                    [:pointer, :pointer], :int,
                    blocking: true
    attach_function :sr_rpc_stream_free,
                    [:pointer], :void

    # Memory cleanup
    attach_function :sr_free_string, [:pointer], :void
    attach_function :sr_free_byte_arr, [:pointer, :int], :void
  end
end
