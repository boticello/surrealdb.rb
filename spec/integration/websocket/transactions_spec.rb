# frozen_string_literal: true

RSpec.describe 'WebSocket sessions and transactions', :integration do
  let(:client) { new_test_client(SurrealHelper::SURREAL_WS_URL) }

  after { client.close }

  it 'carries explicit session and transaction IDs' do
    session_id = client.attach
    expect(session_id).to match(/\A[0-9a-f-]{36}\z/)
    client.signin({ 'user' => SurrealHelper::SURREAL_USER, 'pass' => SurrealHelper::SURREAL_PASS })
    client.use(SurrealHelper::SURREAL_NS, SurrealHelper::SURREAL_DB)
    table = unique_table('websocket_transactions')
    client.query("DEFINE TABLE #{table} SCHEMALESS")

    transaction_id = client.begin_transaction
    expect(transaction_id).to match(/\A[0-9a-f-]{36}\z/)
    client.create(table, { 'value' => 'committed' })
    client.commit

    expect(client.select(table)).to contain_exactly(include('value' => 'committed'))
    expect { client.detach(session_id) }.not_to raise_error
  end
end
