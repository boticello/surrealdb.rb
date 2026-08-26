# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe 'embedded CRUD operations', :embedded, :integration do
  it 'creates, selects, updates, and deletes a record in memory' do
    client = new_persistent_client(ENV.fetch('SURREALDB_EMBEDDED_URL', 'mem://'))
    table = unique_table('embedded_crud')

    created = client.create(table, { 'name' => 'Alice', 'age' => 30 })
    expect(created).to include('name' => 'Alice', 'age' => 30)

    selected = client.select(table)
    expect(selected).to contain_exactly(include('name' => 'Alice', 'age' => 30))

    updated = client.update(table, { 'name' => 'Alice', 'age' => 31 })
    expect(updated).to contain_exactly(include('age' => 31))

    deleted = client.delete(table)
    expect(deleted).to contain_exactly(include('name' => 'Alice', 'age' => 31))
  ensure
    client&.close
  end

  it 'round-trips records through a SurrealKV database' do
    Dir.mktmpdir do |dir|
      endpoint = "surrealkv://#{File.join(dir, 'database')}"
      persistent = new_persistent_client(endpoint)
      persistent.create('embedded_persistence', { 'value' => 'stored' })

      expect(persistent.select('embedded_persistence')).to contain_exactly(include('value' => 'stored'))
      persistent.close
      persistent = new_persistent_client(endpoint)

      expect(persistent.select('embedded_persistence')).to contain_exactly(include('value' => 'stored'))
      expect(Dir).not_to be_empty(dir)
    ensure
      persistent&.close
    end
  end

  it 'round-trips records through a file database' do
    Dir.mktmpdir do |dir|
      persistent = new_persistent_client("file://#{File.join(dir, 'database')}")
      persistent.create('embedded_file', { 'value' => 'stored' })

      expect(persistent.select('embedded_file')).to contain_exactly(include('value' => 'stored'))
    ensure
      persistent&.close
    end
  end

  it 'accepts memory:// as an alias for mem://' do
    memory = SurrealDB::Client.new('memory://')

    expect { memory.connect }.not_to raise_error
  ensure
    memory&.close
  end

  def new_persistent_client(endpoint)
    SurrealDB::Client.new(endpoint).tap do |embedded|
      embedded.connect
      embedded.use('test', 'test')
    end
  end
end
