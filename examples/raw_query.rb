#!/usr/bin/env ruby
# frozen_string_literal: true

require 'surrealdb'

SurrealDB.connect('ws://localhost:8000') do |db|
  db.signin('user' => 'root', 'pass' => 'root')
  db.use('test', 'test')

  # Multi-statement query
  results = db.query(<<~SURQL)
    CREATE product:laptop SET name = 'Laptop', price = 999.99, stock = 50;
    CREATE product:phone SET name = 'Phone', price = 699.99, stock = 100;
    CREATE product:tablet SET name = 'Tablet', price = 449.99, stock = 75;
    SELECT * FROM product WHERE price > 500 ORDER BY price DESC;
  SURQL

  puts "Query returned #{results.length} result sets"
  results.each_with_index do |result, i|
    puts "Statement #{i + 1}: #{result}"
  end

  # Parameterized query
  results = db.query(
    'SELECT * FROM product WHERE price BETWEEN $min AND $max',
    { 'min' => 400, 'max' => 800 }
  )
  puts "\nProducts between $400-$800: #{results}"

  # Cleanup
  db.delete('product')
end
