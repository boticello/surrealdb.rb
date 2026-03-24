# frozen_string_literal: true

module SurrealDB
  # Represents the SurrealDB NONE value, which is distinct from NULL (nil).
  # NONE indicates the absence of a value, while NULL is an explicit null.
  class None
    INSTANCE = new.freeze

    def self.instance
      INSTANCE
    end

    def inspect
      'SurrealDB::NONE'
    end

    def to_s
      'NONE'
    end

    def ==(other)
      other.is_a?(None)
    end
    alias eql? ==

    def hash
      self.class.hash
    end

    def nil?
      false
    end
  end

  NONE = None.instance
end
