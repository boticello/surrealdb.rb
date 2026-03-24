#!/usr/bin/env ruby
# frozen_string_literal: true

require 'surrealdb'

SurrealDB.connect('ws://localhost:8000') do |db|
  # Root-level auth
  db.signin('user' => 'root', 'pass' => 'root')
  db.use('test', 'test')

  version = db.version
  puts "Connected to SurrealDB #{version}"

  # Set connection variables
  db.set('app_version', '1.0')
  results = db.query('RETURN $app_version')
  puts "Variable: #{results}"

  # Invalidate and re-authenticate
  db.invalidate
  db.signin('user' => 'root', 'pass' => 'root')
  db.use('test', 'test')

  puts 'Re-authenticated successfully'
end
