# frozen_string_literal: true

RSpec.describe SurrealDB::Client do
  describe 'URL scheme dispatch' do
    it 'creates a WebSocket connection for ws://' do
      client = described_class.new('ws://localhost:8000')
      expect(client.connection).to be_a(SurrealDB::Connections::WebSocket)
    end

    it 'creates a WebSocket connection for wss://' do
      client = described_class.new('wss://localhost:8000')
      expect(client.connection).to be_a(SurrealDB::Connections::WebSocket)
    end

    it 'creates an HTTP connection for http://' do
      client = described_class.new('http://localhost:8000')
      expect(client.connection).to be_a(SurrealDB::Connections::HTTP)
    end

    it 'creates an HTTP connection for https://' do
      client = described_class.new('https://localhost:8000')
      expect(client.connection).to be_a(SurrealDB::Connections::HTTP)
    end

    it 'raises ArgumentError for unsupported schemes' do
      expect { described_class.new('ftp://localhost') }.to raise_error(ArgumentError, /unsupported URL scheme/)
    end
  end

  describe 'live query gating' do
    let(:client) { described_class.new('http://localhost:8000') }

    it 'raises UnsupportedError for #live on HTTP' do
      expect { client.live('table') }.to raise_error(SurrealDB::UnsupportedError, /live queries/)
    end

    it 'raises UnsupportedError for #subscribe on HTTP' do
      expect { client.subscribe('uuid') {} }.to raise_error(SurrealDB::UnsupportedError) # rubocop:disable Lint/EmptyBlock
    end

    it 'raises UnsupportedError for #kill on HTTP' do
      expect { client.kill('uuid') }.to raise_error(SurrealDB::UnsupportedError)
    end
  end

  describe 'session/transaction gating' do
    let(:client) { described_class.new('http://localhost:8000') }

    it 'raises UnsupportedError for #attach on HTTP' do
      expect { client.attach }.to raise_error(SurrealDB::UnsupportedError, /sessions/)
    end

    it 'raises UnsupportedError for #begin_transaction on HTTP' do
      expect { client.begin_transaction }.to raise_error(SurrealDB::UnsupportedError, /transactions/)
    end
  end

  describe '#create data parameter' do
    let(:connection) { instance_double(SurrealDB::Connections::WebSocket, supports_live_queries?: true) }
    let(:client) { described_class.new('ws://localhost:8000') }

    before do
      client.instance_variable_set(:@connection, connection)
    end

    it 'omits data when nil' do
      allow(connection).to receive(:send_request)
      client.create('table')
      expect(connection).to have_received(:send_request).with('create', ['table'])
    end

    it 'includes data when present' do
      allow(connection).to receive(:send_request)
      client.create('table', { 'name' => 'Alice' })
      expect(connection).to have_received(:send_request).with('create', ['table', { 'name' => 'Alice' }])
    end

    it 'includes data even when falsy (false)' do
      allow(connection).to receive(:send_request)
      client.create('table', false)
      expect(connection).to have_received(:send_request).with('create', ['table', false])
    end
  end

  describe '#send_rpc' do
    let(:connection) { instance_double(SurrealDB::Connections::WebSocket, supports_live_queries?: true) }
    let(:client) { described_class.new('ws://localhost:8000') }

    before do
      client.instance_variable_set(:@connection, connection)
      allow(connection).to receive(:send_request).and_return('ok')
    end

    it 'forwards arbitrary method calls' do
      result = client.send_rpc('custom_method', [1, 2, 3])
      expect(connection).to have_received(:send_request).with('custom_method', [1, 2, 3])
      expect(result).to eq('ok')
    end
  end

  describe '#run version parameter' do
    let(:connection) { instance_double(SurrealDB::Connections::WebSocket, supports_live_queries?: true) }
    let(:client) { described_class.new('ws://localhost:8000') }

    before do
      client.instance_variable_set(:@connection, connection)
      allow(connection).to receive(:send_request)
    end

    it 'passes nil version by default' do
      client.run('fn::test', 'arg1')
      expect(connection).to have_received(:send_request).with('run', ['fn::test', nil, ['arg1']])
    end

    it 'passes explicit version when given' do
      client.run('fn::test', 'arg1', version: '1.0.0')
      expect(connection).to have_received(:send_request).with('run', ['fn::test', '1.0.0', ['arg1']])
    end
  end
end
