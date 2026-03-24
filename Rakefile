# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = ["--tag", "~integration"]
end

RSpec::Core::RakeTask.new("spec:integration") do |t|
  t.rspec_opts = ["--tag", "integration"]
end

RSpec::Core::RakeTask.new("spec:all")

RuboCop::RakeTask.new

task default: %i[rubocop spec]
