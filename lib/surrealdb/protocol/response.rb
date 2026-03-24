# frozen_string_literal: true

module SurrealDB
  module Protocol
    # Parses RPC responses and extracts results or raises appropriate errors.
    module Response
      module_function

      # Extracts the result from a decoded RPC response, raising on error.
      #
      # @param data [Hash] decoded CBOR response
      # @return [Object] the result value
      # @raise [ServerError] if the response contains an error
      # @raise [ProtocolError] if the response is malformed
      def extract_result(data)
        raise ProtocolError, "malformed response: expected Hash, got #{data.class}" unless data.is_a?(Hash)

        err = data['error']
        if err && !err.is_a?(SurrealDB::None) && !err.equal?(SurrealDB::NONE)
          raise_server_error(err)
        elsif data.key?('result')
          data['result']
        else
          raise ProtocolError, "response missing both 'result' and 'error' keys"
        end
      end

      # @param err [Hash, String] error payload from the RPC response
      # @raise [ServerError]
      def raise_server_error(err)
        case err
        when Hash
          raise ServerError.from_response(err)
        when String
          raise ServerError, err
        else
          raise ServerError, err.to_s
        end
      end

      private_class_method :raise_server_error
    end
  end
end
