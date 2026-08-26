# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'embedded query operations', :embedded, :integration do
  let(:client) { SurrealDB::Client.new('mem://') }

  after { client.close }

  it 'returns every normal, parameterized, and multi-statement result' do
    client.connect
    client.use('test', 'test')

    results = client.query('RETURN 1; RETURN $value; RETURN 3;', { 'value' => 2 })

    expect(results.map { |result| result['result'] }).to eq([1, 2, 3])
  end

  it 'returns structured query_raw results' do
    client.connect
    client.use('test', 'test')

    results = client.query_raw('RETURN 1; RETURN 2;')

    expect(results).to all(be_a(SurrealDB::QueryResult))
    expect(results).to all(be_ok)
    expect(results.map(&:result)).to eq([1, 2])
  end
end
