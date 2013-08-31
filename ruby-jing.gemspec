require File.expand_path("../lib/jing", __FILE__)
require "date"

Gem::Specification.new do |s|
  s.name        = "ruby-jing"
  s.version     = Jing::VERSION
  s.date        = Date.today
  s.summary     = "RelaxNG schema validation using Jing"
  s.description =<<-DESC
    RelaxNG schema validation using Jing
  DESC
  s.authors     = ["Skye Shaw"]
  s.email       = "skye.shaw@gmail.com"
  s.test_files  = Dir["test/**/*.*"] 
  s.extra_rdoc_files = %w[README.rdoc]
  s.files       = Dir["lib/**/*.rb"] + s.test_files + s.extra_rdoc_files
  s.homepage    = "http://github.com/sshaw/ruby-jing"
  s.license     = "MIT"
  s.add_dependency "optout", ">= 0.0.2"
  s.add_development_dependency "rake", "~> 0.9.2"
end
