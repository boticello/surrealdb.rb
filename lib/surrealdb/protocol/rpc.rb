# frozen_string_literal: true

module SurrealDB
  module Protocol
    # Handles RPC request/response framing over CBOR.
    # Thread-safe request ID generation.
    class RPC
      def initialize
        @id_counter = 0
        @id_mutex = Mutex.new
      end

      # Encodes an RPC request to CBOR bytes.
      #
      # @param method [String] RPC method name
      # @param params [Array] method parameters
      # @return [Array(Integer, String)] request ID and encoded CBOR bytes
      def encode_request(method, params = [])
        id = next_id
        payload = {
          "id" => id,
          "method" => method,
          "params" => CBOR::Encoder.prepare(params)
        }
        [id, ::CBOR.encode(payload)]
      end

      # Decodes a CBOR response and resolves SurrealDB types.
      #
      # @param data [String] CBOR-encoded binary string
      # @return [Hash] decoded response with resolved types
      def decode_response(data)
        raw = ::CBOR.decode(data)
        CBOR::Decoder.resolve(raw)
      end

      private

      def next_id
        @id_mutex.synchronize do
          @id_counter += 1
        end
      end
    end
  end
end
