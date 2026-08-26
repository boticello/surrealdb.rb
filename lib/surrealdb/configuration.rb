# frozen_string_literal: true

module SurrealDB
  # Global configuration for the SurrealDB SDK.
  #
  # Configure via {SurrealDB.configure}:
  #
  # @example
  #   SurrealDB.configure do |config|
  #     config.timeout = 60
  #     config.logger = Logger.new($stdout)
  #   end
  class Configuration
    # @return [Integer] default request timeout in seconds (default: 30)
    attr_accessor :timeout

    # @return [Logger, nil] optional logger for connection debug output
    attr_accessor :logger

    # Sets default timeout to 30 seconds with no logger.
    def initialize
      @timeout = 30
      @logger = nil
    end
  end
end
