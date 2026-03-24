# frozen_string_literal: true

require "net/http"
require "uri"

module SurrealDB
  module Connections
    # HTTP transport for SurrealDB RPC.
    #
    # Each request is a synchronous POST to /rpc with a CBOR body.
    # Does not support live queries or sessions.
    class HTTP < Base
      def initialize(url, **options)
        super
        @timeout = options.fetch(:timeout, SurrealDB.configuration.timeout)
        @http = nil
        @namespace = nil
        @database = nil
        @auth_token = nil
      end

      def connect
        uri = URI.parse(@url)
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = (uri.scheme == "https")
        @http.open_timeout = @timeout
        @http.read_timeout = @timeout

        if @http.use_ssl?
          @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        @http.start
        @connected = true
      end

      def close
        return unless @connected

        @http&.finish if @http&.started?
        @connected = false
        @http = nil
      end

      def send_request(method, params = [])
        raise ConnectionError, "not connected" unless @connected

        _id, encoded = @rpc.encode_request(method, params)

        # Intercept use() calls to track ns/db for headers
        track_use(method, params)

        request = build_request(encoded)
        response = execute_request(request)

        decoded = @rpc.decode_response(response.body)
        result = Protocol::Response.extract_result(decoded)

        track_auth(method, params, result)
        result
      end

      private

      def build_request(body)
        uri = URI.parse(@url)
        path = uri.path.empty? ? "/rpc" : uri.path

        req = Net::HTTP::Post.new(path)
        req["Content-Type"] = "application/cbor"
        req["Accept"] = "application/cbor"
        req["Authorization"] = "Bearer #{@auth_token}" if @auth_token
        req["surreal-ns"] = @namespace if @namespace
        req["surreal-db"] = @database if @database
        req.body = body
        req
      end

      def execute_request(request)
        response = @http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise ConnectionError, "HTTP #{response.code}: #{response.message}"
        end

        response
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        raise TimeoutError, "HTTP request timed out: #{e.message}"
      rescue Errno::ECONNREFUSED, Errno::ECONNRESET, SocketError => e
        @connected = false
        raise ConnectionError, "HTTP connection error: #{e.message}"
      end

      def track_use(method, params)
        return unless method == Protocol::Methods::USE

        @namespace = params[0] if params[0]
        @database = params[1] if params[1]
      end

      def track_auth(method, params, result)
        case method
        when Protocol::Methods::SIGNIN, Protocol::Methods::SIGNUP
          @auth_token = extract_token(result)
        when Protocol::Methods::AUTHENTICATE
          @auth_token = params[0]
        when Protocol::Methods::INVALIDATE
          @auth_token = nil
        end
      end

      def extract_token(result)
        case result
        when String then result
        when Hash then result["access"] || result["token"]
        end
      end
    end
  end
end
