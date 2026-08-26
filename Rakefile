# frozen_string_literal: true

require 'bundler/gem_helper'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Bundler::GemHelper.install_tasks(name: 'surrealdb')

begin
  require 'yard'
  YARD::Rake::YardocTask.new do |t|
    t.options = ['--markup', 'markdown', '--no-private']
    t.files = ['lib/**/*.rb']
  end
rescue LoadError
  # yard not available
end

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ['--tag', '~integration']
end

RSpec::Core::RakeTask.new('spec:integration') do |t|
  t.rspec_opts = ['--tag', 'integration']
end

RSpec::Core::RakeTask.new('spec:all')

RuboCop::RakeTask.new

task default: %i[rubocop spec]
