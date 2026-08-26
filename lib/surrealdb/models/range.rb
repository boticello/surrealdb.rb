# frozen_string_literal: true

module SurrealDB
  # An inclusive range bound (value is included in the range).
  #
  # @example
  #   bound = SurrealDB::BoundIncluded.new(1)
  #   bound.value  # => 1
  class BoundIncluded
    # @return [Object] the bound value
    attr_reader :value

    # @param value [Object]
    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(BoundIncluded) && other.value == @value
    end
    alias eql? ==

    def hash
      [self.class, @value].hash
    end

    def inspect
      "BoundIncluded(#{@value.inspect})"
    end
  end

  # An exclusive range bound (value is excluded from the range).
  #
  # @example
  #   bound = SurrealDB::BoundExcluded.new(10)
  #   bound.value  # => 10
  class BoundExcluded
    # @return [Object] the bound value
    attr_reader :value

    # @param value [Object]
    def initialize(value)
      @value = value
    end

    def ==(other)
      other.is_a?(BoundExcluded) && other.value == @value
    end
    alias eql? ==

    def hash
      [self.class, @value].hash
    end

    def inspect
      "BoundExcluded(#{@value.inspect})"
    end
  end

  # A SurrealDB range with optional begin and end bounds.
  #
  # Used to represent SurrealDB's range type in queries and record IDs.
  #
  # @example Half-open range: 1..10
  #   range = SurrealDB::Range.new(
  #     SurrealDB::BoundIncluded.new(1),
  #     SurrealDB::BoundExcluded.new(10)
  #   )
  class Range
    # @return [BoundIncluded, BoundExcluded, nil] lower bound (nil = unbounded)
    attr_reader :begin_bound

    # @return [BoundIncluded, BoundExcluded, nil] upper bound (nil = unbounded)
    attr_reader :end_bound

    # @param begin_bound [BoundIncluded, BoundExcluded, nil] lower bound
    # @param end_bound [BoundIncluded, BoundExcluded, nil] upper bound
    def initialize(begin_bound, end_bound)
      @begin_bound = begin_bound
      @end_bound = end_bound
    end

    def ==(other)
      other.is_a?(Range) && other.begin_bound == @begin_bound && other.end_bound == @end_bound
    end
    alias eql? ==

    def hash
      [self.class, @begin_bound, @end_bound].hash
    end

    def inspect
      "SurrealDB::Range(#{@begin_bound.inspect}..#{@end_bound.inspect})"
    end
  end
end
