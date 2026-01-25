# frozen_string_literal: true

require "bundler/setup"
require "rake/testtask"
require "erb"
require "yaml"
require "active_record"
require "active_record/tasks/database_tasks"

require_relative "test/test_helper"

ADAPTERS = %w[sqlite3 postgresql mysql2 trilogy].freeze

def database_config(adapter)
  path = File.expand_path("test/database.yml", __dir__)
  yaml = ERB.new(File.read(path)).result
  YAML.safe_load(yaml, aliases: true).fetch(adapter)
end

def with_connection(adapter)
  ActiveRecord::Base.establish_connection(database_config(adapter))
  yield
ensure
  ActiveRecord::Base.connection_pool.disconnect!
end

task default: "display:notice"

namespace :display do
  task :notice do
    puts
    puts "Run tests with: bundle exec rake test:<adapter>"
    puts "Adapters: #{ADAPTERS.join(', ')}"
    puts
  end
end

ADAPTERS.each do |adapter|
  namespace :test do
    task "setup_#{adapter}" do
      ENV["ARADAPTER"] = adapter
    end

    desc "Run tests with #{adapter}"
    Rake::TestTask.new(adapter) do |t|
      t.libs << "test"
      t.libs << "lib"
      t.test_files = FileList["test/**/*_test.rb"]
    end

    task adapter => "setup_#{adapter}"
  end
end

namespace :db do
  desc "Create test database for adapter"
  task :create, [:adapter] do |_, args|
    adapter = args.fetch(:adapter)
    ActiveRecord::Tasks::DatabaseTasks.create(database_config(adapter))
  end

  desc "Drop test database for adapter"
  task :drop, [:adapter] do |_, args|
    adapter = args.fetch(:adapter)
    ActiveRecord::Tasks::DatabaseTasks.drop(database_config(adapter))
  end

  desc "Load schema for adapter"
  task :schema, [:adapter] do |_, args|
    adapter = args.fetch(:adapter)
    require_relative "test/support/schema_loader"
    with_connection(adapter) do
      TestSupport::SchemaLoader.apply_schema!(adapter: adapter)
    end
  end

  desc "Create database and load schema for adapter"
  task :prepare, [:adapter] => [:create, :schema]
end

ADAPTERS.each do |adapter|
  namespace :db do
    desc "Create test database for #{adapter}"
    task "create:#{adapter}" do
      Rake::Task["db:create"].invoke(adapter)
    end

    desc "Drop test database for #{adapter}"
    task "drop:#{adapter}" do
      Rake::Task["db:drop"].invoke(adapter)
    end

    desc "Load schema for #{adapter}"
    task "schema:#{adapter}" do
      Rake::Task["db:schema"].invoke(adapter)
    end

    desc "Create and load schema for #{adapter}"
    task "prepare:#{adapter}" do
      Rake::Task["db:prepare"].invoke(adapter)
    end
  end
end
