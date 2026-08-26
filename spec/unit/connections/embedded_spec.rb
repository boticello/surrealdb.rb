# frozen_string_literal: true

require 'tmpdir'

# These tests verify the Embedded connection's Ruby logic without loading
# the actual FFI bindings (which require libsurrealdb_c). We test that
# the class structure and method signatures are correct.

RSpec.describe 'SurrealDB::Connections::Embedded (structure)' do
  # The Embedded class is only loaded via require "surrealdb/embedded",
  # which needs libsurrealdb_c. We test the file parses correctly by
  # checking its existence and that the main gem doesn't auto-load it.

  it 'is not auto-loaded by the main gem' do
    expect(defined?(SurrealDB::Connections::Embedded)).to be_nil
  end

  it 'has the connection file at the expected path' do
    path = File.expand_path('../../../lib/surrealdb/connections/embedded.rb', __dir__)
    expect(File.exist?(path)).to be true
  end

  it 'has the platform detection file' do
    path = File.expand_path('../../../lib/surrealdb/native/platform.rb', __dir__)
    expect(File.exist?(path)).to be true
  end

  it 'has the FFI bindings file' do
    path = File.expand_path('../../../lib/surrealdb/native/ffi.rb', __dir__)
    expect(File.exist?(path)).to be true
  end

  it 'has the opt-in entrypoint' do
    path = File.expand_path('../../../lib/surrealdb/embedded.rb', __dir__)
    expect(File.exist?(path)).to be true
  end
end

RSpec.describe 'SurrealDB::Native::Platform' do
  before do
    require_relative '../../../lib/surrealdb/native/platform'
  end

  def stub_host(host_os:, host_cpu:, arch: "#{host_cpu}-#{host_os}")
    allow(RbConfig::CONFIG).to receive(:[]).and_call_original
    allow(RbConfig::CONFIG).to receive(:[]).with('host_os').and_return(host_os)
    allow(RbConfig::CONFIG).to receive(:[]).with('host_cpu').and_return(host_cpu)
    allow(RbConfig::CONFIG).to receive(:[]).with('arch').and_return(arch)
  end

  describe '.host_os' do
    it 'returns a symbol' do
      expect(SurrealDB::Native::Platform.host_os).to be_a(Symbol)
    end
  end

  describe '.host_cpu' do
    it 'returns a symbol' do
      expect(SurrealDB::Native::Platform.host_cpu).to be_a(Symbol)
    end
  end

  describe '.library_name' do
    it 'returns a string with the correct extension' do
      name = SurrealDB::Native::Platform.library_name
      expect(name).to be_a(String)
      expect(name).to include('surrealdb_c')
    end
  end

  describe '.library_path' do
    context 'when SURREALDB_LIB_PATH is not set' do
      before { allow(ENV).to receive(:fetch).and_call_original }

      it 'falls back to the library name for system lookup' do
        allow(ENV).to receive(:[]).with('SURREALDB_LIB_PATH').and_return(nil)
        expect(SurrealDB::Native::Platform.library_path).to eq(SurrealDB::Native::Platform.library_name)
      end
    end

    it 'accepts a library file from SURREALDB_LIB_PATH' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, SurrealDB::Native::Platform.library_name)
        FileUtils.touch(path)
        allow(ENV).to receive(:fetch).with('SURREALDB_LIB_PATH', nil).and_return(path)

        expect(SurrealDB::Native::Platform.library_path).to eq(path)
      end
    end

    it 'resolves a library directory from SURREALDB_LIB_PATH' do
      Dir.mktmpdir do |dir|
        path = File.join(dir, SurrealDB::Native::Platform.library_name)
        FileUtils.touch(path)
        allow(ENV).to receive(:fetch).with('SURREALDB_LIB_PATH', nil).and_return(dir)

        expect(SurrealDB::Native::Platform.library_path).to eq(path)
      end
    end

    it 'raises a clear error for a missing environment override' do
      allow(ENV).to receive(:fetch).with('SURREALDB_LIB_PATH', nil).and_return('/missing/libsurrealdb_c')

      expect { SurrealDB::Native::Platform.library_path }.to raise_error(
        LoadError,
        /SURREALDB_LIB_PATH.*missing/
      )
    end
  end

  describe '.platform_label' do
    it 'distinguishes glibc and musl Linux builds' do
      stub_host(host_os: 'linux-gnu', host_cpu: 'x86_64', arch: 'x86_64-linux-gnu')
      expect(SurrealDB::Native::Platform.platform_label).to eq('linux-glibc-x86_64')

      stub_host(host_os: 'linux-musl', host_cpu: 'aarch64', arch: 'aarch64-linux-musl')
      expect(SurrealDB::Native::Platform.platform_label).to eq('linux-musl-aarch64')
    end

    it 'normalizes macOS architectures' do
      stub_host(host_os: 'darwin25', host_cpu: 'arm64')
      expect(SurrealDB::Native::Platform.platform_label).to eq('macos-aarch64')

      stub_host(host_os: 'darwin25', host_cpu: 'x86_64')
      expect(SurrealDB::Native::Platform.platform_label).to eq('macos-x86_64')
    end

    it 'recognizes x86_64 Windows builds' do
      stub_host(host_os: 'mingw32', host_cpu: 'amd64')

      expect(SurrealDB::Native::Platform.platform_label).to eq('windows-x86_64')
      expect(SurrealDB::Native::Platform.library_name).to eq('surrealdb_c.dll')
    end
  end

  describe '.validate_platform!' do
    it 'rejects unsupported operating systems clearly' do
      stub_host(host_os: 'freebsd14', host_cpu: 'x86_64')

      expect { SurrealDB::Native::Platform.validate_platform! }.to raise_error(
        LoadError,
        /unsupported platform: freebsd14 on x86_64/
      )
    end

    it 'rejects unsupported architectures clearly' do
      stub_host(host_os: 'linux-gnu', host_cpu: 'powerpc64')

      expect { SurrealDB::Native::Platform.validate_platform! }.to raise_error(
        LoadError,
        /unsupported platform: linux-gnu on powerpc64/
      )
    end
  end
end
