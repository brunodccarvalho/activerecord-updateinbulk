# frozen_string_literal: true

require_relative "bench_helper"

adapter = BenchHelper.setup_database!
puts "Adapter: #{adapter}"

COMPARISON_ROW_COUNTS = [10, 100, 1000].freeze
TABLE_FACTOR = 5

BenchHelper.section("update_in_bulk vs individual updates vs update_all(constant)")

COMPARISON_ROW_COUNTS.each do |n|
  BenchHelper.seed_books(n * TABLE_FACTOR)
  ids = Book.pluck(:id).shuffle.take(n)
  updates = ids.each_with_object({}) { |id, h| h[id] = { name: "Updated #{id}" } }

  BenchHelper.subsection("#{n} rows")
  Benchmark.ips do |x|
    x.time = 5
    x.warmup = 2
    x.report("update_in_bulk") do
      BenchHelper.in_transaction { Book.update_in_bulk(updates) }
    end
    x.report("update!") do
      BenchHelper.in_transaction do
        books = Book.where(id: updates.keys).index_by(&:id)
        updates.each { |id, attrs| books[id].update!(attrs) }
      end
    end
    x.report("update_all") do
      BenchHelper.in_transaction { Book.where(id: ids).update_all(name: "Constant Name") }
    end
    x.compare!
  end
end
