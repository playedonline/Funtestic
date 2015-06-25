# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'Funtestic/version'

Gem::Specification.new do |spec|
  spec.name          = "funtestic"
  spec.version       = Funtestic::VERSION
  spec.authors       = ["chenbauer"]
  spec.email         = ["chen@funtomic.com"]
  spec.description   = %q{abtesting framework based on Split gem, with several adjustments to our needs}
  spec.summary       = %q{Funtomic's abtesting gem}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'redis',           '>= 2.1'
  spec.add_dependency 'redis-namespace', '>= 1.1.0'
  spec.add_dependency 'sinatra',         '>= 1.2.6'
  spec.add_dependency 'sinatra-contrib'
  spec.add_dependency 'simple-random'

  # Ruby 1.8 doesn't include JSON in the std lib
  if RUBY_VERSION < "1.9"
    spec.add_dependency 'json',            '>= 1.7.7'
  end

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'bundler',     '~> 1.3'
  spec.add_development_dependency 'rspec',       '~> 2.14'
  spec.add_development_dependency 'rack-test',   '>= 0.5.7'
  spec.add_development_dependency 'coveralls'
end
