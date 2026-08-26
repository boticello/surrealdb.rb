# frozen_string_literal: true

module SurrealDB
  # Represents the SurrealDB NONE value, distinct from NULL ({NilClass}).
  #
  # NONE indicates the absence of a value; NULL is an explicit null.
  # Use {NONE} (the singleton) rather than constructing instances directly.
  #
  # @example
  #   result = db.query("SELECT * FROM person WHERE name = 'nobody'")
  #   result.first == SurrealDB::NONE  # => true when no match
  class None
    # @return [None] the singleton NONE instance
    INSTANCE = new.freeze

    # @return [None]
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
