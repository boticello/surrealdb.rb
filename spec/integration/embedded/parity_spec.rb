# frozen_string_literal: true

require 'spec_helper'
require 'bigdecimal'
require 'timeout'

RSpec.describe 'embedded and WebSocket parity', :embedded, :integration do
  before do
    skip 'set SURREALDB_PARITY=1 with a running SurrealDB server' unless ENV['SURREALDB_PARITY'] == '1'
  end

  it 'returns the same canonical query values' do
    embedded = SurrealDB::Client.new('mem://')
    embedded.connect
    embedded.use(SurrealHelper::SURREAL_NS, SurrealHelper::SURREAL_DB)
    websocket = new_test_client(SurrealHelper::SURREAL_WS_URL)
    payload = {
      'none' => SurrealDB::NONE,
      'record' => SurrealDB::RecordID.new('person', 'one'),
      'decimal' => BigDecimal('1.25'),
      'geometry' => SurrealDB::GeometryPoint.new(1.0, 2.0)
    }

    embedded_result = embedded.query_raw('RETURN $payload', { 'payload' => payload }).first.result
    websocket_result = websocket.query_raw('RETURN $payload', { 'payload' => payload }).first.result

    expect(embedded_result).to eq(payload)
    expect(websocket_result).to eq(embedded_result)
  ensure
    embedded&.close
    websocket&.close
  end

  it 'delivers equivalent live-query notifications' do
    embedded = SurrealDB::Client.new('mem://')
    embedded.connect
    embedded.use(SurrealHelper::SURREAL_NS, SurrealHelper::SURREAL_DB)
    websocket = new_test_client(SurrealHelper::SURREAL_WS_URL)

    embedded_notification = create_and_receive(embedded, unique_table('embedded_parity_live'))
    websocket_notification = create_and_receive(websocket, unique_table('websocket_parity_live'))

    expect(embedded_notification['action']).to eq('CREATE')
    expect(websocket_notification['action']).to eq(embedded_notification['action'])
    expect(websocket_notification['result']['value']).to eq(embedded_notification['result']['value'])
  ensure
    embedded&.close
    websocket&.close
  end

  def create_and_receive(client, table)
    client.query("DEFINE TABLE #{table} SCHEMALESS")
    live_query_id = client.live(table)
    notifications = Queue.new
    client.subscribe(live_query_id) { |notification| notifications << notification }
    client.create(table, { 'value' => 1 })
    Timeout.timeout(5) { notifications.pop }
  ensure
    client.kill(live_query_id) if live_query_id
  end
end
