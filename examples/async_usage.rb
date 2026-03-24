#!/usr/bin/env ruby
# frozen_string_literal: true

# Demonstrates using the SurrealDB SDK with the `async` gem.
#
# The SDK's WebSocket connection uses ConditionVariable#wait which is
# compatible with Ruby's Fiber scheduler. This means it works
# transparently inside Async blocks.
#
# gem install async
# ruby examples/async_usage.rb

require "surrealdb"

begin
  require "async"
rescue LoadError
  warn "This example requires the 'async' gem: gem install async"
  exit 1
end

Async do
  SurrealDB.connect("ws://localhost:8000") do |db|
    db.signin("user" => "root", "pass" => "root")
    db.use("test", "test")

    db.create("async_test", { "name" => "from async", "time" => Time.now.to_s })

    results = db.select("async_test")
    puts "Records: #{results}"

    db.delete("async_test")
  end
end
