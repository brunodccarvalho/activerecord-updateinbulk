# frozen_string_literal: true

# Suppress noisy minitest headers, progress dots, and skip message.
ENV["MT_NO_SKIP_MSG"] = "1"
Minitest::ProgressReporter.prepend(Module.new {
  def record(_result) = ""
})
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
    io.puts "#{summary}, SEED=#{options[:seed]}"
  end
})
