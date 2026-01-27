# -*- encoding: utf-8 -*-
# stub: trilogy 2.10.0 ruby lib
# stub: ext/trilogy-ruby/extconf.rb

Gem::Specification.new do |s|
  s.name = "trilogy".freeze
  s.version = "2.10.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["GitHub Engineering".freeze]
  s.date = "1980-01-02"
  s.email = "opensource+trilogy@github.com".freeze
  s.extensions = ["ext/trilogy-ruby/extconf.rb".freeze]
  s.files = ["ext/trilogy-ruby/extconf.rb".freeze]
  s.homepage = "https://github.com/trilogy-libraries/trilogy".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "A friendly MySQL-compatible library for Ruby, binding to libtrilogy".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<bigdecimal>.freeze, [">= 0"])
  s.add_development_dependency(%q<rake-compiler>.freeze, ["~> 1.0"])
  s.add_development_dependency(%q<minitest>.freeze, ["~> 5.5"])
end
