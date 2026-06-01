# frozen_string_literal: true

source "https://rubygems.org"

gemspec

case ENV["RAILS_VERSION"]
when "main"
  gem "rails", github: "rails/rails", branch: "main"
when String
  gem "rails", "~> #{ENV.fetch("RAILS_VERSION")}"
end

group :development, :test do
  gem "rubocop"
  gem "rubocop-minitest"
  gem "rubocop-rails"
  gem "rubocop-performance"
  gem "rake"
  gem "irb"
  gem "rdoc"
  gem "benchmark-ips"
  gem "byebug"
  gem "minitest"
end

platforms :ruby do
  gem "mysql2"
  gem "pg"
  gem "sqlite3"
  gem "trilogy"
end
