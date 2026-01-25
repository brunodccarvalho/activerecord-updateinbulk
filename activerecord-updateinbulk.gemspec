# frozen_string_literal: true

require File.expand_path("../lib/activerecord-updateinbulk/version", __FILE__)

Gem::Specification.new do |spec|
  spec.name = "activerecord-updateinbulk"
  spec.version = ActiveRecord::UpdateInBulk::VERSION
  spec.authors = ["Bruno Carvalho"]
  spec.email = ["bruno.carvalho.feup@gmail.com"]

  spec.summary = "Bulk update extension for ActiveRecord"
  spec.description = "Methods to update efficiently many records in a table with different values"
  spec.homepage = "https://github.com/bruno/activerecord-updateinbulk"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activerecord", ">= 8.0"
  spec.add_development_dependency "rake"
end
