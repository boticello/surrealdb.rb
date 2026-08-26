# frozen_string_literal: true

module SurrealDB
  # Wraps a table name to disambiguate table-level operations from
  # record-level operations that accept a "table:id" string.
  #
  # Pass a {Table} to {Client#select}, {Client#create}, etc. when you
  # want to operate on the whole table rather than a single record.
  #
  # @example
  #   table = SurrealDB::Table.new("person")
  #   db.select(table)   # SELECT * FROM person
  #   db.create(table, { "name" => "Alice" })
  class Table
    # @return [String] the table name
    attr_reader :name

    # @param name [String] must be non-empty
    # @raise [ArgumentError] if name is nil or empty
    def initialize(name)
      raise ArgumentError, 'table name must be a non-empty string' if name.nil? || name.empty?

      @name = name.freeze
    end

    def to_s
      @name
    end

    def inspect
      "SurrealDB::Table(#{@name})"
    end

    def ==(other)
      other.is_a?(Table) && other.name == @name
    end
    alias eql? ==

    def hash
      [self.class, @name].hash
    end
  end
end
