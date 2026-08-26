# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'embedded connection options', :embedded, :integration do
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

  it 'rejects an embedded URL without a scheme separator' do
    expect { SurrealDB::Client.new('mem:') }.to raise_error(ArgumentError, %r{must include ://})
  end
end
