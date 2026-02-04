# frozen_string_literal: true

require "bundler/setup"
require "benchmark/ips"
require "active_record"
require "activerecord-updateinbulk"

require_relative "../test/support/database"
require_relative "../test/models"

# StreamReport that suppresses warmup output but keeps results.
class QuietStreamReport < Benchmark::IPS::Job::StreamReport
  def start_warming = nil
  def warming(*) = nil
  def warmup_stats(*) = nil
  def start_running = nil
end

module BenchHelper
  module_function

  def setup_database!
    ActiveRecord::Base.establish_connection(TestSupport::Database.config)
    TestSupport::Database.apply_schema!
    ActiveRecord::Base.logger = nil
    adapter
  end

  def seed_books(count)
    Book.delete_all
    rows = count.times.map do |i|
      { id: i + 1, name: "Book #{i}", pages: rand(50..500), format: %w[paperback hardcover ebook].sample }
    end
    Book.insert_all(rows)
  end

  def in_transaction
    ActiveRecord::Base.transaction do
      yield
      raise ActiveRecord::Rollback
    end
  end

  def section(title)
    puts
    puts "=" * 20 + " " + title
  end

  def subsection(subtitle)
    puts "--- #{subtitle} ---"
  end
end
