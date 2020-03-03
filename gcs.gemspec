# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gcs/version'

Gem::Specification.new do |spec|
  spec.name          = "gcs"
  spec.version       = Gcs::VERSION
  spec.authors       = ["Groovenauts, Inc."]
  spec.email         = ["tech@groovenauts.jp"]

  spec.summary       = %q{Groovenauts' wrapper library for Google Cloud Storage with google-api-ruby-client}
  spec.description   = %q{Groovenauts' wrapper library for Google Cloud Storage with google-api-ruby-client}
  spec.homepage      = "https://github.com/groovenauts/gcs-ruby"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rake-compiler"
  spec.add_development_dependency "rspec"
  spec.add_dependency "google-api-client"
end
