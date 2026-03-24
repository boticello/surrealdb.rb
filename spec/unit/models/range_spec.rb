# frozen_string_literal: true

RSpec.describe SurrealDB::Range do
  let(:bound_a) { SurrealDB::BoundIncluded.new(1) }
  let(:bound_b) { SurrealDB::BoundExcluded.new(10) }

  it 'stores begin and end bounds' do
    range = described_class.new(bound_a, bound_b)
    expect(range.begin_bound).to eq(bound_a)
    expect(range.end_bound).to eq(bound_b)
  end

  it 'supports equality' do
    a = described_class.new(bound_a, bound_b)
    b = described_class.new(SurrealDB::BoundIncluded.new(1), SurrealDB::BoundExcluded.new(10))
    expect(a).to eq(b)
    expect(a.hash).to eq(b.hash)
  end

  it 'is not equal when bounds differ' do
    a = described_class.new(bound_a, bound_b)
    b = described_class.new(bound_b, bound_a)
    expect(a).not_to eq(b)
  end

  it 'supports nil bounds' do
    range = described_class.new(nil, bound_b)
    expect(range.begin_bound).to be_nil
  end

  it 'has a readable inspect' do
    range = described_class.new(bound_a, bound_b)
    expect(range.inspect).to include('SurrealDB::Range')
  end
end

RSpec.describe SurrealDB::BoundIncluded do
  it 'wraps a value' do
    bound = described_class.new(5)
    expect(bound.value).to eq(5)
  end

  it 'supports equality' do
    a = described_class.new(5)
    b = described_class.new(5)
    expect(a).to eq(b)
    expect(a).not_to eq(described_class.new(6))
    expect(a).not_to eq(SurrealDB::BoundExcluded.new(5))
  end
end

RSpec.describe SurrealDB::BoundExcluded do
  it 'wraps a value' do
    bound = described_class.new(10)
    expect(bound.value).to eq(10)
  end

  it 'supports equality' do
    a = described_class.new(10)
    b = described_class.new(10)
    expect(a).to eq(b)
    expect(a).not_to eq(described_class.new(11))
    expect(a).not_to eq(SurrealDB::BoundIncluded.new(10))
  end
end
