# frozen_string_literal: true

# Embedded SurrealDB usage examples.
#
# Prerequisites:
#   gem install surrealdb surrealdb-embedded
#
# Set SURREALDB_LIB_PATH to the directory containing libsurrealdb_c:
#   export SURREALDB_LIB_PATH=../surrealdb.c/target/release
#
# Run:
#   ruby examples/embedded_usage.rb

require 'surrealdb/embedded'

puts '=== Embedded SurrealDB Examples ==='
puts

# ---------------------------------------------------------------------------
# 1. In-memory database (volatile)
# ---------------------------------------------------------------------------
puts '--- 1. In-memory CRUD ---'

SurrealDB.connect('mem://') do |db|
  db.use('examples', 'crud')

  # Create
  alice = db.create('person', { 'name' => 'Alice', 'age' => 30 })
  puts "Created: #{alice}"

  # Read
  people = db.select('person')
  puts "All people: #{people}"

  # Update
  db.merge('person:alice', { 'email' => 'alice@example.com' })
  updated = db.select('person:alice')
  puts "Updated: #{updated}"

  # Delete
  db.delete('person:alice')
  remaining = db.select('person')
  puts "After delete: #{remaining.length} records"
end

puts

# ---------------------------------------------------------------------------
# 2. SurrealQL queries with parameters
# ---------------------------------------------------------------------------
puts '--- 2. SurrealQL Queries ---'

SurrealDB.connect('mem://') do |db|
  db.use('examples', 'queries')

  db.create('product', { 'name' => 'Widget', 'price' => 9.99 })
  db.create('product', { 'name' => 'Gadget', 'price' => 24.99 })
  db.create('product', { 'name' => 'Gizmo', 'price' => 14.99 })

  # Parameterized query
  results = db.query(
    'SELECT * FROM product WHERE price > $min_price ORDER BY price',
    { 'min_price' => 10 }
  )
  puts "Products over $10: #{results}"

  # Structured results with timing
  raw_results = db.query_raw('SELECT * FROM product; SELECT count() FROM product;')
  raw_results.each do |qr|
    if qr.ok?
      puts "  #{qr.time}: #{qr.result}"
    else
      puts "  Error: #{qr.error}"
    end
  end
end

puts

# ---------------------------------------------------------------------------
# 3. SurrealDB types
# ---------------------------------------------------------------------------
puts '--- 3. SurrealDB Types ---'

SurrealDB.connect('mem://') do |db|
  db.use('examples', 'types')

  # RecordID
  rid = SurrealDB::RecordID.new('user', 'alice')
  db.create(rid, { 'name' => 'Alice' })
  puts "RecordID: #{rid}"

  # Duration
  dur = SurrealDB::Duration.parse('2h30m')
  puts "Duration: #{dur} (#{dur.secs} seconds)"

  # Geometry
  point = SurrealDB::GeometryPoint.new(-122.4194, 37.7749)
  db.create('location', {
              'name' => 'San Francisco',
              'coords' => point
            })
  puts "GeometryPoint: #{point.inspect}"

  # NONE (distinct from nil)
  puts "NONE: #{SurrealDB::NONE.inspect} (nil?=#{SurrealDB::NONE.nil?})"
end

puts

# ---------------------------------------------------------------------------
# 4. Live queries
# ---------------------------------------------------------------------------
puts '--- 4. Live Queries ---'

SurrealDB.connect('mem://') do |db|
  db.use('examples', 'live')

  live_id = db.live('events')

  notifications = []
  db.subscribe(live_id) do |notification|
    notifications << notification
  end

  # Create records — the subscriber fires
  db.create('events', { 'type' => 'signup', 'user' => 'alice' })
  db.create('events', { 'type' => 'purchase', 'user' => 'bob' })

  # Give the reader thread a moment to deliver
  sleep 0.1

  puts "Received #{notifications.length} notifications:"
  notifications.each do |n|
    puts "  #{n['action']}: #{n['result']}"
  end

  db.kill(live_id)
end

puts

# ---------------------------------------------------------------------------
# 5. Sessions and transactions
# ---------------------------------------------------------------------------
puts '--- 5. Sessions & Transactions ---'

SurrealDB.connect('mem://') do |db|
  db.use('examples', 'transactions')

  session_id = db.attach
  puts "Attached session: #{session_id}"

  db.begin_transaction
  db.create('account', { 'id' => 'a', 'balance' => 100 })
  db.create('account', { 'id' => 'b', 'balance' => 50 })
  db.merge('account:a', { 'balance' => 80 })
  db.merge('account:b', { 'balance' => 70 })
  db.commit

  accounts = db.query('SELECT * FROM account ORDER BY id')
  puts "After transfer: #{accounts}"

  db.detach(session_id)
end

puts

# ---------------------------------------------------------------------------
# 6. Error handling
# ---------------------------------------------------------------------------
puts '--- 6. Error Handling ---'

SurrealDB.connect('mem://') do |db|
  db.use('examples', 'errors')

  begin
    db.query('THIS IS NOT VALID SURREALQL')
  rescue SurrealDB::QueryError => e
    puts "QueryError: #{e.message}"
    puts "  kind: #{e.kind}"
  end

  begin
    db.select('nonexistent:missing')
  rescue SurrealDB::NotFoundError => e
    puts "NotFoundError: #{e.message}"
  end
end

puts

# ---------------------------------------------------------------------------
# 7. Persistent storage (SurrealKV)
# ---------------------------------------------------------------------------
puts '--- 7. Persistent Storage ---'

db_path = File.join(Dir.tmpdir, "surrealdb_embedded_example_#{Process.pid}")

SurrealDB.connect("surrealkv://#{db_path}") do |db|
  db.use('examples', 'persistent')

  db.create('note', { 'text' => 'This survives restarts', 'created' => Time.now.to_s })
  notes = db.select('note')
  puts "Persistent notes: #{notes}"
end

# Clean up
FileUtils.rm_rf(db_path) if File.exist?(db_path)

puts
puts '=== Done ==='
puts '=== Done ==='
