# frozen_string_literal: true

RSpec.describe SurrealDB::None do
  subject(:none) { SurrealDB::NONE }

  it 'is a singleton' do
    expect(none).to equal(described_class.instance)
    expect(none).to equal(SurrealDB::NONE)
  end

  it 'is frozen' do
    expect(none).to be_frozen
  end

  it 'returns false for nil?' do
    expect(none.nil?).to be false
  end

  it 'is equal to other None instances' do
    expect(none).to eq(described_class.instance)
  end

  it 'is not equal to nil' do
    expect(none).not_to be_nil
  end

  it 'has consistent hash' do
    expect(none.hash).to eq(described_class.instance.hash)
  end

  it 'has a readable to_s' do
    expect(none.to_s).to eq('NONE')
  end

  it 'has a readable inspect' do
    expect(none.inspect).to eq('SurrealDB::NONE')
  end
end
