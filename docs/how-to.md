# How-To Guides

Task-oriented recipes for working with SurrealDB embedded in Ruby.

## Build and install libsurrealdb_c

### From the sibling project

```bash
cargo build --release --manifest-path ../surrealdb.c/Cargo.toml
export SURREALDB_LIB_PATH=../surrealdb.c/target/release
```

### From a system install

If `libsurrealdb_c` is in your library path (e.g. `/usr/local/lib`), no
environment variable is needed:

```bash
# macOS
sudo cp target/release/libsurrealdb_c.dylib /usr/local/lib/

# Linux
sudo cp target/release/libsurrealdb_c.so /usr/local/lib/
sudo ldconfig
```

### Diagnose load failures

If you see `LoadError: unable to load libsurrealdb_c`, check:

1. `SURREALDB_LIB_PATH` points to the file or its directory
2. The library was built for your platform (arm64 vs x86_64)
3. The file extension matches your OS (`.dylib`, `.so`, `.dll`)

```ruby
require "surrealdb/native/platform"
puts SurrealDB::Native::Platform.platform_label  # e.g. "macos-aarch64"
puts SurrealDB::Native::Platform.library_name     # e.g. "libsurrealdb_c.dylib"
```

## Choose a storage engine

| Scheme | Persistence | Use case |
|--------|-------------|----------|
| `mem://` | None (volatile) | Tests, scratch data, caching |
| `surrealkv://path` | Durable | Production embedded usage |
| `file://path` | Durable | Alias for `surrealkv://` |

```ruby
# In-memory (fast, ephemeral)
SurrealDB.connect("mem://") { |db| ... }

# Persistent (survives restarts)
SurrealDB.connect("surrealkv://./data/my_app") { |db| ... }
```

## Configure timeouts

Timeouts are integer seconds from 0 to 255. Zero disables the timeout.

```ruby
# Both timeouts at 60s
client = SurrealDB::Client.new("mem://", timeout: 60)

# Different query and transaction timeouts
client = SurrealDB::Client.new(
  "surrealkv://./data",
  query_timeout: 10,
  transaction_timeout: 30
)
```

Global default:

```ruby
SurrealDB.configure do |config|
  config.timeout = 60
end
```

## Use live queries

Embedded connections support live queries — the same API as WebSocket:

```ruby
require "surrealdb/embedded"

SurrealDB.connect("mem://") do |db|
  db.use("app", "live")

  # Start a live query
  live_id = db.live("events")

  # Subscribe with a block
  db.subscribe(live_id) do |notification|
    puts "#{notification['action']}: #{notification['result']}"
  end

  # Create a record — the subscriber fires
  db.create("events", { "type" => "signup", "user" => "alice" })

  # Stop the live query
  db.kill(live_id)
end
```

## Use sessions and transactions

Embedded connections support explicit sessions and transactions:

```ruby
SurrealDB.connect("mem://") do |db|
  db.use("app", "txns")

  # Attach a session
  session_id = db.attach

  # Begin a transaction
  db.begin_transaction

  db.create("account", { "id" => "a", "balance" => 100 })
  db.create("account", { "id" => "b", "balance" => 50 })

  # Transfer: debit A, credit B
  db.merge("account:a", { "balance" => 80 })
  db.merge("account:b", { "balance" => 70 })

  # Commit (or db.cancel to roll back)
  db.commit

  # Detach when done
  db.detach(session_id)
end
```

## Use structured query results

`query` returns raw arrays. `query_raw` gives you per-statement metadata:

```ruby
results = db.query_raw(<<~SQL)
  CREATE person:alice SET name = 'Alice';
  CREATE person:bob SET name = 'Bob';
  SELECT * FROM person;
SQL

results.each do |qr|
  if qr.ok?
    puts "#{qr.time}: #{qr.result}"
  else
    puts "Error: #{qr.error}"
  end
end
```

## Use SurrealDB types

The SDK maps SurrealDB's type system to Ruby classes:

```ruby
# RecordID
rid = SurrealDB::RecordID.new("person", "alice")
rid = SurrealDB::RecordID.parse("person:alice")

# Duration
dur = SurrealDB::Duration.parse("1h30m")
dur.secs   # => 5400
dur.to_f   # => 5400.0

# Geometry
point = SurrealDB::GeometryPoint.new(-122.4194, 37.7749)

# Range
range = SurrealDB::Range.new(
  SurrealDB::BoundIncluded.new(1),
  SurrealDB::BoundExcluded.new(10)
)

# NONE (distinct from nil)
SurrealDB::NONE
```

## Run embedded in tests

Embedded is ideal for tests — no server to start, no port conflicts:

```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.around(:each, :embedded) do |example|
    SurrealDB.connect("mem://") do |db|
      db.use("test", example.full_description)
      @db = db
      example.run
    end
  end
end

# spec/my_spec.rb
it "creates and reads a record", :embedded do
  @db.create("item", { "name" => "Widget" })
  items = @db.select("item")
  expect(items.first["name"]).to eq("Widget")
end
```

## Use one connection per thread

Embedded connections are thread-owned. The thread that calls `connect` (or
`Client.new` + `connect`) owns the connection. Using it from another thread
raises `SurrealDB::ThreadSafetyError`.

```ruby
# Correct: one client per thread
threads = 4.times.map do |i|
  Thread.new do
    SurrealDB.connect("mem://") do |db|
      db.use("app", "thread_#{i}")
      db.create("item", { "thread" => i })
    end
  end
end
threads.each(&:join)
```
