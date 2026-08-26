# frozen_string_literal: true

require 'spec_helper'
require 'bigdecimal'

RSpec.describe 'embedded CBOR boundary', :embedded, :integration do
  let(:client) do
    SurrealDB::Client.new('mem://').tap do |embedded|
      embedded.connect
      embedded.use('test', 'test')
    end
  end

  after { client.close }

  it 'preserves nested primitive values through the C RPC boundary' do
    table = unique_table('embedded_cbor')
    value = {
      'string' => 'hello',
      'integer' => 42,
      'float' => 1.25,
      'boolean' => true,
      'null' => nil,
      'nested' => [{ 'value' => 'inside' }]
    }

    created = client.create(table, value)
    selected = client.select(table).first

    expect(created).to include(value)
    expect(selected).to include(value)
  end

  it 'preserves canonical tagged values and keeps NONE distinct from null' do
    tagged = {
      'none' => SurrealDB::NONE,
      'table' => SurrealDB::Table.new('person'),
      'record' => SurrealDB::RecordID.new('person', 'one'),
      'decimal' => BigDecimal('1.25'),
      'datetime' => Time.utc(2026, 8, 26, 12, 34, 56),
      'duration' => SurrealDB::Duration.new(3600, 500),
      'range' => SurrealDB::Range.new(
        SurrealDB::BoundIncluded.new(1),
        SurrealDB::BoundExcluded.new(3)
      ),
      'geometry' => SurrealDB::GeometryPoint.new(1.0, 2.0)
    }

    returned = client.query_raw('RETURN $tagged', { 'tagged' => tagged }).first.result
    expect(returned).to eq(tagged)

    none, null = client.query_raw('RETURN NONE; RETURN NULL;').map(&:result)
    expect(none).to equal(SurrealDB::NONE)
    expect(null).to be_nil

    uuid = client.query_raw("RETURN u'018f2f8c-8d43-7ad2-9c5a-4a2cc7bc9a51';").first.result
    expect(uuid).to eq('018f2f8c-8d43-7ad2-9c5a-4a2cc7bc9a51')
  end
end
