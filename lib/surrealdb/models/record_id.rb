# frozen_string_literal: true

module SurrealDB
  # Represents a SurrealDB record identifier (table + id).
  #
  # A RecordID uniquely identifies a record within a table.
  # The id component can be a string, integer, array, or object.
  class RecordID
    # @return [String] table name
    attr_reader :table

    # @return [Object] record identifier (String, Integer, Array, Hash)
    attr_reader :id

    # @param table [String]
    # @param id [Object]
    def initialize(table, id)
      raise ArgumentError, 'table must be a non-empty string' if table.nil? || table.to_s.empty?

      @table = table.to_s.freeze
      @id = id
    end

    # Parses a "table:id" string into a RecordID.
    #
    # @param str [String] e.g. "user:john", "post:123"
    # @return [RecordID]
    # @raise [ArgumentError] if the string is not a valid record ID
    def self.parse(str)
      parts = str.to_s.split(':', 2)
      raise ArgumentError, "invalid record ID: #{str}" if parts.length < 2 || parts[0].empty?

      table = parts[0]
      raw_id = parts[1]

      # Unwrap angle bracket escaping: ⟨...⟩
      raw_id = raw_id[1..-2] if raw_id.start_with?("\u27E8") && raw_id.end_with?("\u27E9")

      id = try_numeric(raw_id)
      new(table, id)
    end

    def to_s
      id_str = format_id(@id)
      "#{@table}:#{id_str}"
    end

    def inspect
      "SurrealDB::RecordID(#{self})"
    end

    def ==(other)
      other.is_a?(RecordID) && other.table == @table && other.id == @id
    end
    alias eql? ==

    def hash
      [self.class, @table, @id].hash
    end

    class << self
      private

      def try_numeric(str)
        Integer(str)
      rescue ArgumentError, TypeError
        str
      end
    end

    private

    def format_id(value)
      case value
      when String then escape_string_id(value)
      when Array then "[#{value.map { |v| format_id(v) }.join(', ')}]"
      when Hash then format_object_id(value)
      else value.to_s
      end
    end

    def escape_string_id(str)
      return str if str.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)

      "\u27E8#{str}\u27E9"
    end

    def format_object_id(obj)
      inner = obj.map { |k, v| "#{k}: #{format_id(v)}" }.join(', ')
      "{ #{inner} }"
    end
  end
end
