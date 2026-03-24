# frozen_string_literal: true

module SurrealDB
  class Configuration
    # @return [Integer] request timeout in seconds
    attr_accessor :timeout

    # @return [Logger, nil] optional logger instance
    attr_accessor :logger

    def initialize
      @timeout = 30
      @logger = nil
    end
  end
end
