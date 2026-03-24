# frozen_string_literal: true

module SurrealDB
  module Connections
    # Abstract base class for SurrealDB transport connections.
    # Subclasses must implement #connect, #close, and #send_request.
    class Base
      # @return [String] base URL
      attr_reader :url

      # @return [Protocol::RPC]
      attr_reader :rpc

      def initialize(url, **_options)
        @url = url
        @rpc = Protocol::RPC.new
        @connected = false
      end

      # Opens the transport connection.
      # @return [void]
      def connect
        raise NotImplementedError
      end

      # Closes the transport connection.
      # @return [void]
      def close
        raise NotImplementedError
      end

      # Sends an RPC method call and returns the result.
      # @param method [String] RPC method name
      # @param params [Array] method parameters
      # @return [Object] decoded result
      def send_request(method, params = [])
        raise NotImplementedError
      end

      # @return [Boolean]
      def connected?
        @connected
      end

      # Whether this connection supports live queries.
      # @return [Boolean]
      def supports_live_queries?
        false
      end
    end
  end
end
