# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "bundler/setup"
require "active_record"
require "activerecord-updateinbulk"
require "active_support/test_case"
require "minitest/autorun"

# Suppress noisy minitest headers and skip message.
ENV["MT_NO_SKIP_MSG"] = "1"
Minitest::SummaryReporter.prepend(Module.new {
  def start
    self.start_time = Minitest.clock_time
    self.sync = io.respond_to?(:"sync=")
    self.old_sync, io.sync = io.sync, true if sync
  end

  def report
    self.total_time = Minitest.clock_time - start_time

    aggregate = results.group_by { |r| r.failure.class }
    aggregate.default = []
    self.failures = aggregate[Minitest::Assertion].size
    self.errors   = aggregate[Minitest::UnexpectedError].size
    self.skips    = aggregate[Minitest::Skip].size

    io.sync = old_sync

    aggregated_results io
    io.puts "#{summary} SEED=#{options[:seed]}"
  end
})

require_relative "support/adapter_helper"
require_relative "support/database_config"
require_relative "support/schema_loader"
require_relative "support/test_case"

adapter = TestSupport::DatabaseConfig.adapter


ActiveRecord::Base.establish_connection(TestSupport::DatabaseConfig.config_for(adapter))
TestSupport::SchemaLoader.apply_schema!

Dir[File.expand_path("models/*.rb", __dir__)].sort.each { |f| require f }
