# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'embedded connection lifecycle', :embedded, :integration do
  let(:client) { SurrealDB::Client.new('mem://') }

  after { client.close }

  it 'rejects requests after close' do
    client.connect
    client.close

    expect { client.version }.to raise_error(SurrealDB::ConnectionError, /not connected/)
  end

  it 'rejects duplicate connect without closing the live context' do
    client.connect

    expect { client.connect }.to raise_error(SurrealDB::ConnectionError, /already connected/)
    expect(client.version).to be_a(String)
  end

  it 'keeps the connection usable after a native RPC error' do
    client.connect
    client.use('test', 'test')

    expect { client.send_rpc('not-a-real-method') }.to raise_error(SurrealDB::ServerError)
    expect(client.version).to be_a(String)
  end

  it 'fails loudly when used from a second thread' do
    client.connect
    error = Thread.new do
      client.version
    rescue StandardError => e
      e
    end.value

    expect(error).to be_a(SurrealDB::ThreadSafetyError)
    expect(error.message).to include('create one Client per thread')
    expect(client.version).to be_a(String)
  end

  it 'prevents a second thread from freeing the connection' do
    client.connect
    error = Thread.new do
      client.close
    rescue StandardError => e
      e
    end.value

    expect(error).to be_a(SurrealDB::ThreadSafetyError)
    expect(client.version).to be_a(String)
  end

  it 'clears session and transaction state before reconnecting' do
    client.connect
    client.attach
    client.use('test', 'test')
    client.begin_transaction
    client.close

    client.connect
    client.use('test', 'test')
    expect(client.query_raw('RETURN 1').first.result).to eq(1)
  end
end
