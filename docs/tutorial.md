# Tutorial: Your First Embedded App

This tutorial walks you through building a small Ruby program that uses
SurrealDB embedded — no server process required.

## Prerequisites

- Ruby >= 3.2
- The `surrealdb-embedded` gem
- `libsurrealdb_c` on your system (or a path to it)

## Step 1: Install

```bash
gem install surrealdb surrealdb-embedded
```

If you're using Bundler:

```ruby
# Gemfile
gem "surrealdb"
gem "surrealdb-embedded"
```

## Step 2: Build the native library

The embedded gem talks to SurrealDB's Rust core through a C shared library.
If you have the sibling `surrealdb.c` project:

```bash
cargo build --release --manifest-path ../surrealdb.c/Cargo.toml
```

This produces `libsurrealdb_c.dylib` (macOS), `libsurrealdb_c.so` (Linux),
or `surrealdb_c.dll` (Windows) in `target/release/`.

Tell Ruby where to find it:

```bash
export SURREALDB_LIB_PATH=../surrealdb.c/target/release
```

## Step 3: Hello, embedded

Create `hello_embedded.rb`:

```ruby
require "surrealdb/embedded"

SurrealDB.connect("mem://") do |db|
  db.use("tutorial", "getting_started")

  # Create a record
  db.create("greeting", { "message" => "Hello from embedded SurrealDB!" })

  # Read it back
  result = db.select("greeting")
  puts result
  # => [{"id" => "greeting:...", "message" => "Hello from embedded SurrealDB!"}]
end
```

Run it:

```bash
ruby hello_embedded.rb
```

That's it — no Docker, no server, no network. The database lives entirely
in your process.

## Step 4: Persist data with SurrealKV

`mem://` is volatile. Switch to `surrealkv://` for durable storage:

```ruby
require "surrealdb/embedded"

SurrealDB.connect("surrealkv://./my_data") do |db|
  db.use("tutorial", "persistent")

  db.create("note", { "text" => "This survives restarts" })
  notes = db.select("note")
  puts notes
end
```

The `./my_data` directory is created automatically. Run the script twice —
the second run sees the first run's data.

`file://` is an alias for `surrealkv://`:

```ruby
SurrealDB.connect("file://./my_data") { |db| ... }
```

## Step 5: Query with SurrealQL

For anything beyond basic CRUD, use `query`:

```ruby
SurrealDB.connect("mem://") do |db|
  db.use("tutorial", "queries")

  db.create("person", { "name" => "Alice", "age" => 30 })
  db.create("person", { "name" => "Bob", "age" => 25 })
  db.create("person", { "name" => "Charlie", "age" => 35 })

  # Parameterized query
  results = db.query(
    "SELECT * FROM person WHERE age > $min",
    { "min" => 28 }
  )
  puts results
  # => [{"name" => "Alice", "age" => 30}, {"name" => "Charlie", "age" => 35}]
end
```

## Step 6: Handle errors

SurrealDB returns structured errors. Catch them by type:

```ruby
begin
  db.query("THIS IS NOT VALID SURREALQL")
rescue SurrealDB::QueryError => e
  puts "Query failed: #{e.message}"
  puts "Error kind: #{e.kind}"
end
```

## Next steps

- [How-to guides](how-to.md) — task-oriented recipes for common patterns
- [Explanation](explanation.md) — how the embedded connection works internally
- [Reference](reference.md) — complete embedded API surface
