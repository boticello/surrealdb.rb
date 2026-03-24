# frozen_string_literal: true

module SurrealDB
  # Wraps a single statement result from a multi-statement query.
  # Each statement in a SurrealQL query produces a separate QueryResult
  # with its own status, timing, result data, and optional error.
  class QueryResult
    # @return [String] "OK" or "ERR"
    attr_reader :status

    # @return [String, nil] execution time (e.g. "1.234ms")
    attr_reader :time

    # @return [Object] the statement's result data
    attr_reader :result

    # @return [String, nil] error message if status is "ERR"
    attr_reader :error

    def initialize(status:, time: nil, result: nil, error: nil)
      @status = status
      @time = time
      @result = result
      @error = error
    end

    # @return [Boolean] true when the statement executed without error
    def ok?
      status == "OK"
    end

    # @return [Boolean] true when the statement produced an error
    def error?
      status == "ERR"
    end

    # Builds a QueryResult from a server response hash.
    # @param data [Hash] e.g. {"status"=>"OK", "time"=>"1ms", "result"=>[...]}
    # @return [QueryResult]
    def self.from_response(data)
      return new(status: "OK", result: data) unless data.is_a?(Hash) && data.key?("status")

      new(
        status: data["status"],
        time: data["time"],
        result: data["result"],
        error: data["error"]
      )
    end

    def inspect
      "#<SurrealDB::QueryResult status=#{@status.inspect} time=#{@time.inspect}>"
    end
  end
end
