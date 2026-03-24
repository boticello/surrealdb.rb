# frozen_string_literal: true

RSpec.describe SurrealDB::RecordID do
  describe '.new' do
    it 'stores table and id' do
      rid = described_class.new('user', 'john')
      expect(rid.table).to eq('user')
      expect(rid.id).to eq('john')
    end

    it 'accepts integer ids' do
      rid = described_class.new('post', 42)
      expect(rid.id).to eq(42)
    end

    it 'rejects nil table' do
      expect { described_class.new(nil, 'x') }.to raise_error(ArgumentError)
    end

    it 'rejects empty table' do
      expect { described_class.new('', 'x') }.to raise_error(ArgumentError)
    end
  end

  describe '.parse' do
    it 'parses simple string id' do
      rid = described_class.parse('user:john')
      expect(rid.table).to eq('user')
      expect(rid.id).to eq('john')
    end

    it 'parses numeric id as integer' do
      rid = described_class.parse('post:42')
      expect(rid.table).to eq('post')
      expect(rid.id).to eq(42)
    end

    it 'parses angle-bracket escaped ids' do
      rid = described_class.parse("user:\u27E8some-complex-id\u27E9")
      expect(rid.id).to eq('some-complex-id')
    end

    it 'rejects strings without colon' do
      expect { described_class.parse('invalid') }.to raise_error(ArgumentError)
    end

    it 'rejects empty table' do
      expect { described_class.parse(':id') }.to raise_error(ArgumentError)
    end
  end

  describe '#to_s' do
    it 'formats simple string ids' do
      expect(described_class.new('user', 'john').to_s).to eq('user:john')
    end

    it 'formats integer ids' do
      expect(described_class.new('post', 42).to_s).to eq('post:42')
    end

    it 'escapes ids with special characters' do
      rid = described_class.new('user', 'some-complex-id')
      expect(rid.to_s).to eq("user:\u27E8some-complex-id\u27E9")
    end

    it 'formats array ids' do
      rid = described_class.new('test', [1, 'two'])
      expect(rid.to_s).to eq('test:[1, two]')
    end
  end

  describe 'equality' do
    it 'considers same table and id as equal' do
      a = described_class.new('user', 'john')
      b = described_class.new('user', 'john')
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it 'considers different ids as not equal' do
      a = described_class.new('user', 'john')
      b = described_class.new('user', 'jane')
      expect(a).not_to eq(b)
    end
  end
end
