# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'
require 'timeout'

RSpec.describe 'embedded connection lifecycle', :embedded, :integration do
  let(:client) { SurrealDB::Client.new('mem://') }

  after { client.close }

  def race_connection_owners(race_client)
    started = Queue.new
    release = Queue.new
    results = Queue.new
    threads = 2.times.map do
      Thread.new do
        started << true
        release.pop
        race_client.connect
        results << :connected
        race_client.close
      rescue StandardError => e
        results << e
      end
    end
    2.times { started.pop }
    2.times { release << true }
    threads.each(&:join)
    2.times.map { results.pop }
  end

  def abandoned_client_status
    lib_dir = File.expand_path('../../../lib', __dir__)
    script = <<~RUBY
      require 'weakref'
      require 'surrealdb/embedded'
      client = SurrealDB::Client.new('mem://')
      client.connect
      connection = WeakRef.new(client.connection)
      client = nil
      3.times { GC.start }
      alive = connection.weakref_alive?
      warn 'embedded connection remained reachable after GC' if alive
      exit!(alive ? 1 : 0)
    RUBY
    wait_thread = nil
    stdin, output, wait_thread = Open3.popen2e(RbConfig.ruby, '-I', lib_dir, '-e', script)
    stdin.close
    [Timeout.timeout(5) { wait_thread.value }, output.read]
  ensure
    if wait_thread&.alive?
      Process.kill('TERM', wait_thread.pid)
      wait_thread.join(1)
      Process.kill('KILL', wait_thread.pid) if wait_thread.alive?
      wait_thread.join
    end
    output&.close
  end

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

  it 'allows only one thread to claim a new connection owner' do
    outcomes = race_connection_owners(SurrealDB::Client.new('mem://'))

    expect(outcomes.count(:connected)).to eq(1)
    expect(outcomes.count { |outcome| outcome.is_a?(SurrealDB::ThreadSafetyError) }).to eq(1)
    expect(outcomes.find { |outcome| outcome.is_a?(SurrealDB::ThreadSafetyError) }.message)
      .to include('create one Client per thread')
  end

  it 'does not hold the GVL while a worker-owned request sleeps' do
    client = SurrealDB::Client.new('mem://')
    started = Queue.new
    worker = Thread.new do
      client.connect
      started << true
      client.query('RETURN sleep(500ms)')
    ensure
      client.close
    end

    started.pop
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    sleep 0.1
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    expect(elapsed).to be < 0.3
    Timeout.timeout(3) { worker.value }
  ensure
    worker&.join
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

  it 'allows an explicit double close without repeating native cleanup' do
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_close).and_call_original
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_free).and_call_original
    client.connect

    expect { client.close }.not_to raise_error
    expect { client.close }.not_to raise_error
    expect(client.connected?).to be(false)
    expect(SurrealDB::Native).to have_received(:sr_surreal_rpc_close).once
    expect(SurrealDB::Native).to have_received(:sr_surreal_rpc_free).once
  end

  it 'does not retain reader threads across 64 connect and close cycles' do
    baseline = Thread.list.count(&:alive?)

    64.times do
      client.connect
      client.close
    end

    expect(Thread.list.count(&:alive?)).to eq(baseline)
  end

  it 'frees the response buffer when decoding raises' do
    raw_ptr = FFI::MemoryPointer.from_string('x')
    response_ptr = FFI::MemoryPointer.new(:pointer)
    response_ptr.write_pointer(raw_ptr)
    connection = client.connection
    allow(connection.rpc).to receive(:decode_response).and_raise(ArgumentError, 'invalid CBOR')
    allow(SurrealDB::Native).to receive(:sr_free_byte_arr)

    expect do
      connection.send(:read_and_free_response, response_ptr, 1)
    end.to raise_error(ArgumentError, 'invalid CBOR')

    expect(SurrealDB::Native).to have_received(:sr_free_byte_arr).with(raw_ptr, 1)
  end

  describe '#check_error!' do
    let(:connection) { client.connection }

    def native_error_pointer(message)
      err_ptr = FFI::MemoryPointer.new(:pointer)
      string_ptr = FFI::MemoryPointer.from_string(message)
      err_ptr.write_pointer(string_ptr)
      [err_ptr, string_ptr]
    end

    it 'maps SR_ERROR to ServerError and frees its native message once' do
      err_ptr, string_ptr = native_error_pointer('recoverable native failure')
      allow(SurrealDB::Native).to receive(:sr_free_string)

      expect { connection.send(:check_error!, SurrealDB::Native::SR_ERROR, err_ptr) }
        .to raise_error(SurrealDB::ServerError, 'recoverable native failure')
      expect(SurrealDB::Native).to have_received(:sr_free_string).with(string_ptr).once
    end

    it 'maps SR_FATAL to ConnectionError and frees its native message once' do
      err_ptr, string_ptr = native_error_pointer('fatal native failure')
      allow(SurrealDB::Native).to receive(:sr_free_string)

      expect { connection.send(:check_error!, SurrealDB::Native::SR_FATAL, err_ptr) }
        .to raise_error(SurrealDB::ConnectionError, /fatal error \(connection poisoned\): fatal native failure/)
      expect(SurrealDB::Native).to have_received(:sr_free_string).with(string_ptr).once
    end

    it 'reports a useful message when the native error pointer is null' do
      err_ptr = FFI::MemoryPointer.new(:pointer)
      err_ptr.write_pointer(FFI::Pointer::NULL)

      expect { connection.send(:check_error!, SurrealDB::Native::SR_ERROR, err_ptr) }
        .to raise_error(SurrealDB::ServerError, 'unknown error (code -2)')
    end
  end

  it 'frees a context when notification stream startup fails' do
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_notifications)
      .and_return(SurrealDB::Native::SR_ERROR)
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_close).and_call_original
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_free).and_call_original

    expect { client.connect }.to raise_error(SurrealDB::ServerError)

    expect(SurrealDB::Native).to have_received(:sr_surreal_rpc_close).once
    expect(SurrealDB::Native).to have_received(:sr_surreal_rpc_free).once
    expect(client.connected?).to be(false)
  end

  it 'frees the context when native close reports an error' do
    client.connect
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_close).and_return(SurrealDB::Native::SR_ERROR)
    allow(SurrealDB::Native).to receive(:sr_surreal_rpc_free).and_call_original

    expect { client.close }.to raise_error(SurrealDB::ServerError)

    expect(SurrealDB::Native).to have_received(:sr_surreal_rpc_free).once
    expect(client.connected?).to be(false)
  end

  it 'releases an abandoned client and its reader thread during garbage collection' do
    process_status, diagnostic = abandoned_client_status

    expect(process_status).to be_success, diagnostic
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
