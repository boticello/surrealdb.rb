# frozen_string_literal: true

module SurrealDB
  class BoundIncluded
    attr_reader :value

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

  class BoundExcluded
    attr_reader :value

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

  class Range
    # @return [BoundIncluded, BoundExcluded, nil]
    attr_reader :begin_bound

    # @return [BoundIncluded, BoundExcluded, nil]
    attr_reader :end_bound

    # @param begin_bound [BoundIncluded, BoundExcluded, nil]
    # @param end_bound [BoundIncluded, BoundExcluded, nil]
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
