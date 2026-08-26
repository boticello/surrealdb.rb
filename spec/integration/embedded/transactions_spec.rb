# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'embedded sessions and transactions', :embedded, :integration do
  let(:client) { SurrealDB::Client.new('mem://') }

  after { client.close }

  it 'attaches and detaches an explicit session' do
    client.connect

    session_id = client.attach
    expect(session_id).to match(/\A[0-9a-f-]{36}\z/)
    client.use('test', 'test')
    expect(client.query_raw('RETURN 1').first.result).to eq(1)
    expect { client.detach(session_id) }.not_to raise_error
  end

  it 'cancels and commits work through explicit transaction IDs' do
    client.connect
    session_id = client.attach
    expect { client.attach }.to raise_error(SurrealDB::ConnectionError, /already attached/)
    client.use('test', 'test')
    table = unique_table('embedded_transactions')
    client.query("DEFINE TABLE #{table} SCHEMALESS")

    cancelled_transaction = client.begin_transaction
    expect(cancelled_transaction).to match(/\A[0-9a-f-]{36}\z/)
    expect { client.begin_transaction }.to raise_error(SurrealDB::ConnectionError, /already active/)
    expect { client.detach(session_id) }.to raise_error(SurrealDB::ConnectionError, /active transaction/)
    client.create(table, { 'value' => 'discarded' })
    client.cancel
    expect(client.select(table)).to be_empty

    committed_transaction = client.begin_transaction
    expect(committed_transaction).to match(/\A[0-9a-f-]{36}\z/)
    client.create(table, { 'value' => 'kept' })
    client.commit
    expect(client.select(table)).to contain_exactly(include('value' => 'kept'))
  end

  it 'clears a transaction consumed by a native timeout' do
    timed = SurrealDB::Client.new('mem://', transaction_timeout: 1)
    timed.connect
    timed.attach
    timed.use('test', 'test')
    timed.begin_transaction

    expect { timed.query('SLEEP 2s; RETURN 1;') }.to raise_error(SurrealDB::QueryError)
    expect { timed.begin_transaction }.not_to raise_error
    timed.cancel
  ensure
    timed&.close
  end
end
