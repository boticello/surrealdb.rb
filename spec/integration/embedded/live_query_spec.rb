# frozen_string_literal: true

require 'spec_helper'
require 'timeout'

RSpec.describe 'embedded live queries', :embedded, :integration do
  let(:client) { SurrealDB::Client.new('mem://') }

  after { client.close }

  it 'delivers notifications and stops after kill' do
    client.connect
    client.use('test', 'test')
    table = unique_table('embedded_live')
    client.query("DEFINE TABLE #{table} SCHEMALESS")

    live_query_id = client.live(table)
    notifications = Queue.new
    client.subscribe(live_query_id) { |notification| notifications << notification }
    client.create(table, { 'value' => 1 })

    notification = Timeout.timeout(5) { notifications.pop }
    expect(notification['id'].to_s).to eq(live_query_id.to_s)
    expect(notification['action']).to eq('CREATE')
    expect(notification['result']).to include('value' => 1)

    client.kill(live_query_id)
    client.create(table, { 'value' => 2 })
    sleep 0.1
    expect(notifications).to be_empty
  end
end
