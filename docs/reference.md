# Embedded API Reference

This is a quick-reference for the embedded-specific API surface. For the
full SDK reference (shared across all transports), see the
[YARD documentation](https://rubydoc.info/gems/surrealdb).

## Entry point

```ruby
require "surrealdb/embedded"
```

This loads the base SDK, the FFI bindings, and the Embedded connection
class. The base `surrealdb` gem never loads `ffi` or a native library
by itself.

## Connection

### `SurrealDB.connect(url, **options) { |db| ... }`

Opens an embedded connection, yields the `Client`, and closes it when
the block returns.

```ruby
SurrealDB.connect("mem://") do |db|
  db.use("ns", "db")
  # ...
end
```

### `SurrealDB::Client.new(url, **options)`

Creates a client without auto-connecting. Call `#connect` to open.

```ruby
client = SurrealDB::Client.new("surrealkv://./data", query_timeout: 10)
client.connect
# ...
client.close
```

### URL schemes

| Scheme | Engine | Persistence |
|--------|--------|-------------|
| `mem://` | In-memory | None |
| `memory://` | In-memory | None (alias for `mem://`) |
| `surrealkv://path` | SurrealKV | Durable |
| `file://path` | SurrealKV | Durable (alias) |

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `timeout` | Integer (0-255) | 30 | General timeout in seconds |
| `query_timeout` | Integer (0-255) | `timeout` | Query-specific timeout |
| `transaction_timeout` | Integer (0-255) | `timeout` | Transaction-specific timeout |
| `strict` | Boolean | false | Raises `UnsupportedError` if true |

Zero disables the timeout. Values outside 0-255 raise `ArgumentError`.

## Client methods (embedded-supported)

All methods from `SurrealDB::Client` are available. Embedded connections
support all three feature sets:

| Feature | Embedded | WebSocket | HTTP |
|---------|:--------:|:---------:|:----:|
| Queries | Yes | Yes | Yes |
| Live queries | Yes | Yes | No |
| Sessions/transactions | Yes | Yes | No |

### CRUD

```ruby
db.create(resource, data)       # => Hash
db.select(resource)              # => Array or Hash
db.insert(table, data)           # => Array
db.update(resource, data)        # => Object
db.upsert(resource, data)        # => Object
db.merge(resource, data)         # => Object
db.patch(resource, patches)      # => Object
db.delete(resource)              # => Object
db.relate(from, relation, to, data) # => Object
```

`resource` is a `String` (`"person"`, `"person:alice"`), `RecordID`, or
`Table`.

### Queries

```ruby
db.query(sql, vars = {})         # => Array (raw results)
db.query_raw(sql, vars = {})     # => Array<QueryResult>
db.run(function_name, *args)     # => Object
```

### Authentication

```ruby
db.signin(credentials)           # => String (token)
db.signup(credentials)           # => String (token)
db.authenticate(token)           # => void
db.invalidate                    # => void
```

### Variables

```ruby
db.set(key, value)               # => void (alias: `let`)
db.unset(key)                    # => void
```

### Live queries

```ruby
live_id = db.live(table, diff: false)  # => String (UUID)
db.subscribe(live_id) { |notification| ... }
db.kill(live_id)
```

### Sessions and transactions

```ruby
session_id = db.attach           # => String
db.begin_transaction             # => void
db.commit                        # => void
db.cancel                        # => void
db.detach(session_id)            # => void
```

### Info

```ruby
db.version                       # => String
db.info                          # => Hash
db.connected?                    # => Boolean
```

## SurrealDB types

### `SurrealDB::RecordID`

```ruby
rid = SurrealDB::RecordID.new("person", "alice")
rid = SurrealDB::RecordID.parse("person:alice")
rid.table  # => "person"
rid.id     # => "alice"
```

### `SurrealDB::Duration`

```ruby
dur = SurrealDB::Duration.parse("1h30m")
dur.secs        # => 5400
dur.nanos       # => 0
dur.to_f        # => 5400.0
dur.to_s        # => "1h30m"
```

### `SurrealDB::Table`

```ruby
table = SurrealDB::Table.new("person")
table.name  # => "person"
```

### `SurrealDB::NONE`

Singleton representing SurrealDB's NONE value (distinct from `nil`/NULL).

### Geometry types

```ruby
SurrealDB::GeometryPoint.new(longitude, latitude)
SurrealDB::GeometryLine.new(*points)
SurrealDB::GeometryPolygon.new(exterior, *interiors)
SurrealDB::GeometryMultiPoint.new(*points)
SurrealDB::GeometryMultiLine.new(*lines)
SurrealDB::GeometryMultiPolygon.new(*polygons)
SurrealDB::GeometryCollection.new(*geometries)
```

### Range types

```ruby
SurrealDB::BoundIncluded.new(value)
SurrealDB::BoundExcluded.new(value)
SurrealDB::Range.new(begin_bound, end_bound)
```

## Error hierarchy

```
SurrealDB::Error
├── ConnectionError
│   └── ThreadSafetyError
├── TimeoutError
├── ProtocolError
├── UnsupportedError
└── ServerError
    ├── QueryError
    ├── NotFoundError
    ├── NotAllowedError
    ├── AlreadyExistsError
    ├── ValidationError
    ├── InternalServerError
    ├── SerializationError
    ├── ConfigurationError
    └── ThrownError
```

`ServerError` carries structured fields:

```ruby
rescue SurrealDB::ServerError => e
  e.code           # => Integer (JSON-RPC code)
  e.kind           # => String ("Query", "NotFound", etc.)
  e.details        # => Hash
  e.server_cause   # => ServerError (chained cause)
  e.find_cause("NotFound")  # => ServerError or nil
  e.has_kind?("Query")      # => Boolean
end
```

## Configuration

```ruby
SurrealDB.configure do |config|
  config.timeout = 60      # seconds (default: 30)
  config.logger = Logger.new($stdout)
end
```

## Environment variables

| Variable | Description |
|----------|-------------|
| `SURREALDB_LIB_PATH` | Path to `libsurrealdb_c` file or directory |

## Thread safety

- One connection per thread. Cross-thread use raises `ThreadSafetyError`.
- Each connection owns its own Tokio runtime (via the C library).
- `NativeResources` uses a mutex for idempotent cleanup.
- The notification reader thread is joined on `#close`.

## See also

- [Tutorial](tutorial.md) — get started in 5 minutes
- [How-To Guides](how-to.md) — task-oriented recipes
- [Explanation](explanation.md) — architecture and internals
