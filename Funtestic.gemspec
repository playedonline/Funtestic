# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'funtestic/version'

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

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
end
