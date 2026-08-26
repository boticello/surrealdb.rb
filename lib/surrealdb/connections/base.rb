# frozen_string_literal: true

require 'securerandom'

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
        @session_id = nil
        @transaction_id = nil
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

      # Whether this connection supports SurrealQL query result responses.
      # @return [Boolean]
      def supports_queries?
        false
      end

      # Whether this connection supports session and transaction RPC methods.
      # @return [Boolean]
      def supports_sessions?
        false
      end

      private

      def rpc_request_context(method, params)
        case method
        when Protocol::Methods::ATTACH
          attach_context
        when Protocol::Methods::DETACH
          detach_context(params)
        when Protocol::Methods::BEGIN_TXN
          begin_transaction_context(params)
        when Protocol::Methods::COMMIT, Protocol::Methods::CANCEL
          finish_transaction_context
        else
          [params, @session_id, @transaction_id]
        end
      end

      def attach_context
        raise ConnectionError, 'a session is already attached' if @session_id
        raise ConnectionError, 'cannot attach while a transaction is active' if @transaction_id

        [[], SecureRandom.uuid, nil]
      end

      def detach_context(params)
        raise ConnectionError, 'commit or cancel the active transaction before detach' if @transaction_id

        session_id = params.first || @session_id
        raise ConnectionError, 'no session is attached' unless session_id
        raise ConnectionError, 'cannot detach a different session' if @session_id && session_id != @session_id

        [[], session_id, nil]
      end

      def begin_transaction_context(params)
        raise ConnectionError, 'a transaction is already active' if @transaction_id

        [params, @session_id, nil]
      end

      def finish_transaction_context
        raise ConnectionError, 'no transaction is active' unless @transaction_id

        transaction_param = ::CBOR::Tagged.new(
          SurrealDB::CBOR::Tags::UUID_STRING,
          @transaction_id
        )
        [[transaction_param], @session_id, @transaction_id]
      end

      def update_rpc_context_after_success(method, session_id, result)
        case method
        when Protocol::Methods::ATTACH
          @session_id = session_id
          result = session_id
        when Protocol::Methods::DETACH
          @session_id = nil if @session_id == session_id
          @transaction_id = nil if @session_id.nil?
        when Protocol::Methods::BEGIN_TXN
          @transaction_id = result.to_s
        when Protocol::Methods::COMMIT, Protocol::Methods::CANCEL
          @transaction_id = nil
        end
        result
      end

      def reconcile_rpc_context_error(method, error)
        return unless @transaction_id
        return unless [Protocol::Methods::COMMIT, Protocol::Methods::CANCEL].include?(method) ||
                      transaction_timeout_error?(error)

        @transaction_id = nil
      end

      def transaction_timeout_error?(error)
        error.is_a?(QueryError) &&
          error.details.is_a?(Hash) &&
          error.details['kind'] == 'TimedOut'
      end

      def reset_rpc_context!
        @session_id = nil
        @transaction_id = nil
      end
    end
  end
end
