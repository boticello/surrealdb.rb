# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'embedded connection options', :embedded, :integration do
  it 'matches the three-byte native SrOption layout and zero defaults' do
    option = SurrealDB::Native::SrOption.new

    expect(SurrealDB::Native::SrOption.size).to eq(3)
    expect(SurrealDB::Native::SrOption.offset_of(:strict)).to eq(0)
    expect(SurrealDB::Native::SrOption.offset_of(:query_timeout)).to eq(1)
    expect(SurrealDB::Native::SrOption.offset_of(:transaction_timeout)).to eq(2)
    expect(option[:strict]).to be(false)
    expect(option[:query_timeout]).to eq(0)
    expect(option[:transaction_timeout]).to eq(0)
  end

  it 'rejects strict mode because the C RPC path does not implement it' do
    expect do
      SurrealDB::Client.new('mem://', strict: true)
    end.to raise_error(SurrealDB::UnsupportedError, /strict mode is not supported/)
  end

  it 'rejects timeouts outside the C ABI uint8 range' do
    [-1, 256, 1.5, nil].each do |timeout|
      expect do
        SurrealDB::Client.new('mem://', query_timeout: timeout)
      end.to raise_error(ArgumentError, /query_timeout must be an Integer from 0 to 255/)
    end
  end

  it 'accepts independent query and transaction timeouts' do
    client = SurrealDB::Client.new('mem://', query_timeout: 0, transaction_timeout: 255)

    expect { client.connect }.not_to raise_error
  ensure
    client&.close
  end

  it 'propagates query_timeout to native query execution' do
    client = SurrealDB::Client.new('mem://', query_timeout: 1)
    client.connect

    result = client.query_raw('RETURN sleep(1500ms)').first

    expect(result).to be_error
    expect("#{result.result} #{result.error}").to match(/timed out|timeout/i)
  ensure
    client&.close
  end

  it 'rejects an embedded URL without a scheme separator' do
    expect { SurrealDB::Client.new('mem:') }.to raise_error(ArgumentError, %r{must include ://})
  end
end
