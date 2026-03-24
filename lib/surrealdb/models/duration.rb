# frozen_string_literal: true

module SurrealDB
  # Represents a SurrealDB duration with second and nanosecond precision.
  class Duration
    NANOS_PER_MICRO  = 1_000
    NANOS_PER_MILLI  = 1_000_000
    NANOS_PER_SECOND = 1_000_000_000
    NANOS_PER_MINUTE = NANOS_PER_SECOND * 60
    NANOS_PER_HOUR   = NANOS_PER_MINUTE * 60
    NANOS_PER_DAY    = NANOS_PER_HOUR * 24
    NANOS_PER_WEEK   = NANOS_PER_DAY * 7
    NANOS_PER_YEAR   = NANOS_PER_DAY * 365

    # @return [Integer] whole seconds
    attr_reader :secs

    # @return [Integer] nanosecond remainder (0..999_999_999)
    attr_reader :nanos

    # @param secs [Integer]
    # @param nanos [Integer]
    def initialize(secs, nanos = 0)
      total_nanos = (secs * NANOS_PER_SECOND) + nanos
      @secs = total_nanos / NANOS_PER_SECOND
      @nanos = total_nanos % NANOS_PER_SECOND
    end

    UNIT_MAP = {
      'y' => NANOS_PER_YEAR,
      'w' => NANOS_PER_WEEK,
      'd' => NANOS_PER_DAY,
      'h' => NANOS_PER_HOUR,
      'm' => NANOS_PER_MINUTE,
      's' => NANOS_PER_SECOND,
      'ms' => NANOS_PER_MILLI,
      'us' => NANOS_PER_MICRO,
      'µs' => NANOS_PER_MICRO,
      'ns' => 1
    }.freeze

    PARSE_REGEX = /(\d+)(y|w|d|h|ms|m|us|µs|ns|s)/

    # Parses a SurrealDB duration string like "1h30m", "2d3h15m10s".
    # @param str [String]
    # @return [Duration]
    def self.parse(str)
      total_nanos = 0
      matched = false

      str.to_s.scan(PARSE_REGEX) do |amount, unit|
        matched = true
        total_nanos += amount.to_i * UNIT_MAP.fetch(unit)
      end

      raise ArgumentError, "invalid duration: #{str}" unless matched

      new(total_nanos / NANOS_PER_SECOND, total_nanos % NANOS_PER_SECOND)
    end

    # @return [Float] total duration in seconds
    def to_f
      @secs + (@nanos.to_f / NANOS_PER_SECOND)
    end

    # @return [Integer] total nanoseconds
    def total_nanos
      (@secs * NANOS_PER_SECOND) + @nanos
    end

    def to_s
      return '0s' if @secs.zero? && @nanos.zero?

      remaining = total_nanos
      parts = []

      [['y', NANOS_PER_YEAR], ['w', NANOS_PER_WEEK], ['d', NANOS_PER_DAY],
       ['h', NANOS_PER_HOUR], ['m', NANOS_PER_MINUTE], ['s', NANOS_PER_SECOND],
       ['ms', NANOS_PER_MILLI], ['us', NANOS_PER_MICRO], ['ns', 1]].each do |unit, nanos_per|
        next if remaining < nanos_per

        count = remaining / nanos_per
        remaining %= nanos_per
        parts << "#{count}#{unit}"
      end

      parts.join
    end

    def inspect
      "SurrealDB::Duration(#{self})"
    end

    def ==(other)
      other.is_a?(Duration) && other.secs == @secs && other.nanos == @nanos
    end
    alias eql? ==

    def hash
      [self.class, @secs, @nanos].hash
    end
  end
end
