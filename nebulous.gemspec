# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nebulous/version'

Gem::Specification.new do |spec|
  spec.name          = "nebulous"
  spec.version       = Nebulous::VERSION
  spec.authors       = ["Andy Jones"]
  spec.email         = ["andy.jones@jameshall.co.uk"]
  spec.summary       = %q{Handles request-and-response messaging via STOMP}
  #spec.description   = %q{TODO: Write a longer description.}
  #spec.homepage      = ""
  spec.license       = "Closed"

  spec.files         = `hg status -macn0`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = spec.files.grep(%r{^md/})

  spec.requirements << 'STOMP Messaging server'
  spec.requirements << 'Redis server (optional)'

  spec.post_install_message = %w{Nebulous has been installed ...sort of...
                                 ::waves arms noncomittedly::} * ' '

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake",    "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"

  spec.add_runtime_dependency "stomp", '>=1.3.3'
  spec.add_runtime_dependency "redis", '>=3.1.0'
end
