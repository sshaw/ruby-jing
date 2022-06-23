require "date"

Gem::Specification.new do |s|
  s.name        = "ruby-jing"
  s.version     = "0.0.3"
  s.date        = Date.today
  s.summary     = "RELAX NG schema validation using the Jing CLI"
  s.description =<<-DESC
    RELAX NG schema validation using Jing, a Java based RELAX NG validator that emits clear,
    detailed validation errors. ruby-jing validates XML documents by wrapping Jing's java
    command-line user interface.
  DESC
  s.authors     = ["Skye Shaw"]
  s.email       = "skye.shaw@gmail.com"
  s.test_files  = Dir["test/**/*.rb"]
  s.extra_rdoc_files = %w[README.rdoc]
  s.files       = Dir["lib/**/*.{jar,rb}"] + s.test_files + s.extra_rdoc_files
  s.homepage    = "http://github.com/sshaw/ruby-jing"
  s.license     = "MIT"
  s.add_dependency "optout", ">= 0.0.2"
  s.add_development_dependency "bundler"
  s.add_development_dependency "rake", ">= 12.3.3"
  s.add_development_dependency "minitest", "~> 4.0"
end
