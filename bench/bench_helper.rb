# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "activerecord-updateinbulk"
require "active_support/notifications"

require_relative "../test/support/database"

module BenchHelper
  BENCH_TIME = ENV.fetch("BENCH_TIME", "5").to_f
  BENCH_WARMUP = ENV.fetch("BENCH_WARMUP", "2").to_f
  IGNORED_SQL = /\A(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|PRAGMA)\b/i

  BenchmarkResult = Struct.new(:label, :iterations, :seconds, :total_ms, :sql_ms, :ruby_ms, keyword_init: true) do
    def ips
      iterations / seconds
    end

    def ruby_ips
      return Float::INFINITY if ruby_ms <= 0.0

      iterations / (ruby_ms / 1000.0)
    end

    def avg_total_ms
      total_ms / iterations
    end

    def avg_sql_ms
      sql_ms / iterations
    end

    def avg_ruby_ms
      ruby_ms / iterations
    end
  end

  module_function

  def setup_database!
    ActiveRecord::Base.establish_connection(TestSupport::Database.config)
    TestSupport::Database.apply_schema!
    load_models!
    ActiveRecord::Base.logger = nil
    TestSupport::Database.adapter
  end

  def load_models!
    return if defined?(::Book)

    require_relative "../test/models"
  end

  def run_profile(label, time: BENCH_TIME, warmup: BENCH_WARMUP)
    warmup_deadline = monotonic_now + warmup
    while monotonic_now < warmup_deadline
      yield
    end

    sql_ms = 0.0
    callback = lambda do |*args|
      event = ActiveSupport::Notifications::Event.new(*args)
      payload = event.payload
      sql = payload[:sql].to_s
      next if payload[:name] == "SCHEMA" || payload[:cached]
      next if sql.empty? || sql.match?(IGNORED_SQL)

      sql_ms += event.duration
    end

    iterations = 0
    start = monotonic_now
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      deadline = start + time
      while monotonic_now < deadline
        yield
        iterations += 1
      end
    end

    seconds = monotonic_now - start
    total_ms = seconds * 1000.0
    ruby_ms = [total_ms - sql_ms, 0.0].max

    BenchmarkResult.new(
      label:,
      iterations:,
      seconds:,
      total_ms:,
      sql_ms:,
      ruby_ms:
    )
  end

  def report_result(result)
    puts format(
      "  %-22s %8.2f i/s  total %8.3f ms/i  sql %8.3f ms/i  ruby %8.3f ms/i",
      result.label,
      result.ips,
      result.avg_total_ms,
      result.avg_sql_ms,
      result.avg_ruby_ms
    )
  end

  def report_comparison(results)
    fastest_total = results.max_by(&:ips)
    fastest_ruby = results.max_by(&:ruby_ips)

    results.each do |result|
      slower_total = fastest_total.ips / result.ips
      slower_ruby = fastest_ruby.ruby_ips / result.ruby_ips
      puts format(
        "    %-22s total %.2fx slower  ruby %.2fx slower",
        result.label,
        slower_total,
        slower_ruby
      )
    end
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

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
