# frozen_string_literal: true

require "uri"

module SurrealDB
  # Main client for interacting with SurrealDB.
  #
  # Provides a unified API across WebSocket and HTTP transports,
  # selected automatically based on the connection URL scheme.
  #
  # @example
  #   client = SurrealDB::Client.new("ws://localhost:8000")
  #   client.connect
  #   client.use("test", "test")
  #   client.signin(username: "root", password: "root")
  #   results = client.select("users")
  #   client.close
  class Client
    # @return [Connections::Base]
    attr_reader :connection

    # @param url [String] connection URL (ws://, wss://, http://, https://)
    # @param options [Hash] connection options (:timeout, etc.)
    def initialize(url, **options)
      @url = url
      @options = options
      @connection = build_connection(url, **options)
    end

    # Opens the connection to SurrealDB.
    # @return [self]
    def connect
      @connection.connect
      self
    end

    # Closes the connection.
    # @return [void]
    def close
      @connection.close
    end

    # @return [Boolean]
    def connected?
      @connection.connected?
    end

    # --- Namespace / Database ---

    # Selects the namespace and database to use.
    # @param namespace [String]
    # @param database [String]
    # @return [void]
    def use(namespace, database)
      @connection.send_request(Protocol::Methods::USE, [namespace, database])
    end

    # --- Authentication ---

    # Signs in to SurrealDB.
    # @param credentials [Hash] authentication credentials
    # @return [String, Hash] JWT token or tokens hash
    def signin(credentials = {})
      @connection.send_request(Protocol::Methods::SIGNIN, [credentials])
    end

    # Signs up a new user.
    # @param credentials [Hash] signup credentials
    # @return [String, Hash] JWT token or tokens hash
    def signup(credentials = {})
      @connection.send_request(Protocol::Methods::SIGNUP, [credentials])
    end

    # Authenticates with an existing JWT token.
    # @param token [String]
    # @return [void]
    def authenticate(token)
      @connection.send_request(Protocol::Methods::AUTHENTICATE, [token])
    end

    # Invalidates the current session.
    # @return [void]
    def invalidate
      @connection.send_request(Protocol::Methods::INVALIDATE)
    end

    # --- Variables ---

    # Sets a connection-scoped variable.
    # @param key [String]
    # @param value [Object]
    # @return [void]
    def set(key, value)
      @connection.send_request(Protocol::Methods::LET, [key, value])
    end
    alias let set

    # Removes a connection-scoped variable.
    # @param key [String]
    # @return [void]
    def unset(key)
      @connection.send_request(Protocol::Methods::UNSET, [key])
    end

    # --- CRUD ---

    # Selects all records from a table, or a single record by ID.
    # @param resource [String, RecordID, Table] table name, "table:id", or RecordID
    # @return [Array, Hash] records
    def select(resource)
      @connection.send_request(Protocol::Methods::SELECT, [resource_param(resource)])
    end

    # Creates a new record.
    # @param resource [String, RecordID, Table]
    # @param data [Hash, nil] record content
    # @return [Hash] created record
    def create(resource, data = nil)
      params = [resource_param(resource)]
      params << data if data
      @connection.send_request(Protocol::Methods::CREATE, params)
    end

    # Inserts one or more records into a table.
    # @param table [String, Table] table name
    # @param data [Hash, Array<Hash>] record(s) to insert
    # @return [Array] inserted records
    def insert(table, data)
      @connection.send_request(Protocol::Methods::INSERT, [table_param(table), data])
    end

    # Inserts a relation record.
    # @param table [String, Table] relation table name
    # @param data [Hash] relation data (must include :in and :out)
    # @return [Array] inserted relation records
    def insert_relation(table, data)
      @connection.send_request(Protocol::Methods::INSERT_RELATION, [table_param(table), data])
    end

    # Replaces a record or all records in a table.
    # @param resource [String, RecordID, Table]
    # @param data [Hash] replacement content
    # @return [Object] updated record(s)
    def update(resource, data)
      @connection.send_request(Protocol::Methods::UPDATE, [resource_param(resource), data])
    end

    # Upserts a record (insert or update).
    # @param resource [String, RecordID, Table]
    # @param data [Hash] record content
    # @return [Object] upserted record(s)
    def upsert(resource, data)
      @connection.send_request(Protocol::Methods::UPSERT, [resource_param(resource), data])
    end

    # Deep-merges data into a record.
    # @param resource [String, RecordID, Table]
    # @param data [Hash] data to merge
    # @return [Object] merged record(s)
    def merge(resource, data)
      @connection.send_request(Protocol::Methods::MERGE, [resource_param(resource), data])
    end

    # Applies JSON Patch operations to a record.
    # @param resource [String, RecordID, Table]
    # @param patches [Array<Hash>] patch operations
    # @return [Object] patched record(s)
    def patch(resource, patches)
      @connection.send_request(Protocol::Methods::PATCH, [resource_param(resource), patches])
    end

    # Deletes a record or all records from a table.
    # @param resource [String, RecordID, Table]
    # @return [Object] deleted record(s)
    def delete(resource)
      @connection.send_request(Protocol::Methods::DELETE, [resource_param(resource)])
    end

    # Creates a graph relation between two records.
    # @param from [String, RecordID] source record
    # @param relation [String] relation table
    # @param to [String, RecordID] target record
    # @param data [Hash, nil] relation content
    # @return [Object] created relation
    def relate(from, relation, to, data = nil)
      params = [resource_param(from), relation, resource_param(to)]
      params << data if data
      @connection.send_request(Protocol::Methods::RELATE, params)
    end

    # --- Query ---

    # Executes a SurrealQL query.
    # @param sql [String] SurrealQL statement(s)
    # @param vars [Hash] query variables
    # @return [Array] array of result sets (one per statement)
    def query(sql, vars = {})
      params = [sql]
      params << vars unless vars.empty?
      @connection.send_request(Protocol::Methods::QUERY, params)
    end

    # Runs a SurrealDB function.
    # @param function_name [String]
    # @param args [Array] function arguments
    # @return [Object]
    def run(function_name, *args)
      @connection.send_request(Protocol::Methods::RUN, [function_name, nil, args])
    end

    # --- Live Queries ---

    # Starts a live query on a table (WebSocket only).
    # @param resource [String, Table] table name
    # @param diff [Boolean] whether to receive diffs instead of full records
    # @return [String] live query UUID
    def live(resource, diff: false)
      require_live_queries!
      @connection.send_request(Protocol::Methods::LIVE, [table_param(resource), diff])
    end

    # Subscribes to live query notifications.
    # @param live_query_id [String] UUID from #live
    # @yield [Hash] notification with :action and :result keys
    # @return [void]
    def subscribe(live_query_id, &block)
      require_live_queries!
      @connection.on_notification(live_query_id, block)
    end

    # Kills a live query.
    # @param live_query_id [String]
    # @return [void]
    def kill(live_query_id)
      require_live_queries!
      @connection.remove_notification_handler(live_query_id)
      @connection.send_request(Protocol::Methods::KILL, [live_query_id])
    end

    # --- Info ---

    # Returns the SurrealDB server version.
    # @return [String]
    def version
      @connection.send_request(Protocol::Methods::VERSION)
    end

    # Returns info about the current session.
    # @return [Hash, nil]
    def info
      @connection.send_request(Protocol::Methods::INFO)
    end

    private

    def build_connection(url, **options)
      uri = URI.parse(url)
      case uri.scheme
      when "ws", "wss"
        Connections::WebSocket.new(url, **options)
      when "http", "https"
        Connections::HTTP.new(url, **options)
      else
        raise ArgumentError, "unsupported URL scheme: #{uri.scheme}. Use ws://, wss://, http://, or https://"
      end
    end

    def resource_param(resource)
      case resource
      when RecordID then resource.to_s
      when Table then resource.name
      else resource.to_s
      end
    end

    def table_param(resource)
      case resource
      when Table then resource.name
      else resource.to_s
      end
    end

    def require_live_queries!
      return if @connection.supports_live_queries?

      raise UnsupportedError, "live queries require a WebSocket connection (ws:// or wss://)"
    end
  end
end
