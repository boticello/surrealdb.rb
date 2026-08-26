# frozen_string_literal: true

module SurrealDB
  # Base error for all SurrealDB SDK errors.
  class Error < StandardError; end

  # Raised when the connection to SurrealDB fails or is lost.
  class ConnectionError < Error; end

  # Raised when an embedded connection is used from a thread other than
  # the one that called {Connections::Embedded#connect}.
  class ThreadSafetyError < ConnectionError; end

  # Raised when a request exceeds the configured timeout.
  class TimeoutError < Error; end

  # Raised when the server response cannot be decoded.
  class ProtocolError < Error; end

  # Raised when a feature is unavailable on the current transport
  # (e.g. live queries on HTTP).
  class UnsupportedError < Error; end

  # Base class for errors returned by the SurrealDB server.
  # Supports both legacy (code + message) and v3 structured
  # (kind + details + cause chain) error formats.
  class ServerError < Error
    # @return [Integer, nil] JSON-RPC error code
    attr_reader :code

    # @return [String, nil] structured error kind (e.g. "NotFound", "NotAllowed")
    attr_reader :kind

    # @return [Hash, nil] additional error details
    attr_reader :details

    # @return [ServerError, nil] chained cause from the server
    attr_reader :server_cause

    def initialize(message = nil, code: nil, kind: nil, details: nil, server_cause: nil)
      @code = code
      @kind = kind
      @details = details
      @server_cause = server_cause
      super(message)
    end

    # Walk the cause chain looking for a specific kind.
    # @param target_kind [String]
    # @return [ServerError, nil]
    def find_cause(target_kind)
      current = self
      while current
        return current if current.kind == target_kind

        current = current.server_cause
      end
      nil
    end

    # @param target_kind [String]
    # @return [Boolean]
    def has_kind?(target_kind) # rubocop:disable Naming/PredicatePrefix
      !find_cause(target_kind).nil?
    end

    # Populated after subclasses are defined at the bottom of this file.
    KIND_TO_CLASS = {} # rubocop:disable Style/MutableConstant

    # Builds the appropriate ServerError subclass from a parsed error hash.
    # @param data [Hash] parsed error data with string keys
    # @return [ServerError]
    def self.from_response(data)
      return new(data.to_s) unless data.is_a?(Hash)

      kind = data['kind']
      message = data['message'] || data['msg']
      code = data['code']
      details = data['details']

      raw_cause = data['cause']
      cause = raw_cause.is_a?(Hash) ? from_response(raw_cause) : nil

      klass = KIND_TO_CLASS.fetch(kind, self)
      klass.new(message, code: code, kind: kind, details: details, server_cause: cause)
    end
  end

  # Raised when a SurrealQL query fails (syntax error, runtime error, etc.).
  class QueryError < ServerError; end

  # Raised when a requested record or resource does not exist.
  class NotFoundError < ServerError; end

  # Raised when an operation is not permitted (authentication/authorization).
  class NotAllowedError < ServerError; end

  # Raised when creating a record that already exists.
  class AlreadyExistsError < ServerError; end

  # Raised when input fails SurrealDB's validation rules.
  class ValidationError < ServerError; end

  # Raised on an internal SurrealDB server error.
  class InternalServerError < ServerError; end

  # Raised when SurrealDB cannot serialize the response.
  class SerializationError < ServerError; end

  # Raised for SurrealDB configuration errors.
  class ConfigurationError < ServerError; end

  # Raised when SurrealDB throws a value (e.g. THROW statement).
  class ThrownError < ServerError; end

  ServerError::KIND_TO_CLASS.merge!(
    'Query' => QueryError,
    'NotFound' => NotFoundError,
    'NotAllowed' => NotAllowedError,
    'AlreadyExists' => AlreadyExistsError,
    'Validation' => ValidationError,
    'Internal' => InternalServerError,
    'Serialization' => SerializationError,
    'Configuration' => ConfigurationError,
    'Thrown' => ThrownError
  ).freeze
end
