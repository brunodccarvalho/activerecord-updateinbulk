# frozen_string_literal: true

require_relative "bench_helper"

adapter = BenchHelper.setup_database!
puts "Adapter: #{adapter}"

ROW_COUNTS = [10, 100, 1000, 5000].freeze
TABLE_FACTOR = 3

BenchHelper.section("Single-column update")

ROW_COUNTS.each do |n|
  BenchHelper.seed_books(n * TABLE_FACTOR)
  ids = Book.pluck(:id).shuffle.take(n)
  updates = ids.each_with_object({}) { |id, h| h[id] = { name: "Updated #{id}" } }

  BenchHelper.subsection("#{n} rows")
  Benchmark.ips(quiet: true) do |x|
    x.suite = QuietStreamReport.new
    x.time = 5
    x.warmup = 2
    x.report("update_in_bulk(#{n})") do
      BenchHelper.in_transaction { Book.update_in_bulk(updates) }
    end
  end
end

BenchHelper.section("Multi-column update")

ROW_COUNTS.each do |n|
  BenchHelper.seed_books(n * TABLE_FACTOR)
  ids = Book.pluck(:id).shuffle.take(n)
  updates = ids.each_with_object({}) do |id, h|
    h[id] = { name: "Updated #{id}", pages: rand(50..500), format: "hardcover" }
  end

  BenchHelper.subsection("#{n} rows")
  Benchmark.ips(quiet: true) do |x|
    x.suite = QuietStreamReport.new
    x.time = 5
    x.warmup = 2
    x.report("update_in_bulk(#{n})") do
      BenchHelper.in_transaction { Book.update_in_bulk(updates) }
    end
  end
end

BenchHelper.section("Optional keys update")

ROW_COUNTS.each do |n|
  BenchHelper.seed_books(n * TABLE_FACTOR)
  ids = Book.pluck(:id).shuffle.take(n)
  columns = [:name, :pages, :format]
  updates = ids.each_with_object({}) do |id, h|
    subset = columns.sample(rand(1..columns.size))
    attrs = {}
    attrs[:name] = "Updated #{id}" if subset.include?(:name)
    attrs[:pages] = rand(50..500) if subset.include?(:pages)
    attrs[:format] = "ebook" if subset.include?(:format)
    h[id] = attrs
  end

  BenchHelper.subsection("#{n} rows")
  Benchmark.ips(quiet: true) do |x|
    x.suite = QuietStreamReport.new
    x.time = 5
    x.warmup = 2
    x.report("update_in_bulk(#{n})") do
      BenchHelper.in_transaction { Book.update_in_bulk(updates) }
    end
  end
end
