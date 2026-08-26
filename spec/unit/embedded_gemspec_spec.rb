# frozen_string_literal: true

RSpec.describe Gem::Specification do
  let(:base_spec) { described_class.load(File.expand_path('../../surrealdb.gemspec', __dir__)) }
  let(:embedded_spec) { described_class.load(File.expand_path('../../surrealdb-embedded.gemspec', __dir__)) }

  it 'keeps native files out of the default gem' do
    expect(base_spec.files).not_to include('lib/surrealdb/embedded.rb')
    expect(base_spec.files.grep(%r{\Alib/surrealdb/native/})).to be_empty
    expect(base_spec.files).not_to include('lib/surrealdb/connections/embedded.rb')
  end

  it 'ships the complete opt-in entrypoint in the embedded gem' do
    expect(embedded_spec.files).to include(
      'lib/surrealdb/embedded.rb',
      'lib/surrealdb/native/ffi.rb',
      'lib/surrealdb/native/platform.rb',
      'lib/surrealdb/connections/embedded.rb'
    )
  end

  it 'depends on ffi and the exact matching base gem' do
    dependencies = embedded_spec.runtime_dependencies.to_h do |dependency|
      [dependency.name, dependency.requirement.to_s]
    end

    expect(dependencies).to include('ffi' => '~> 1.15', 'surrealdb' => "= #{SurrealDB::VERSION}")
  end
end
