lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nebulous/version'

Gem::Specification.new do |spec|
  spec.name          = "nebulous_stomp"
  spec.version       = Nebulous::VERSION
  spec.authors       = ["Andy Jones"]
  spec.email         = ["andy.jones@twosticksconsulting.co.uk"]
  spec.summary       = %q{Handles request-and-response messaging via STOMP}
  spec.description   = <<~DESC
    A library and protocol to allow disperate systems to ask a question via
    STOMP and receive an answer in return. Optionally, answers can be cached in
    Redis.
  DESC

  spec.license       = "MIT"
  spec.homepage      = "https://bitbucket.org/andy-twosticks/nebulous"

  spec.files         = `hg status -macn0`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = spec.files.grep(%r{^md/})

  spec.requirements << 'STOMP Messaging server'
  spec.requirements << 'Redis server (optional)'

  spec.post_install_message = <<~MESSAGE
    Nebulous has been installed ...sort of...  ::waves arms noncomittedly::
  MESSAGE

  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake",    "~> 10.5"
  spec.add_development_dependency "rspec",   "~> 3.4"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "ripper-tags"

  spec.add_runtime_dependency 'stomp',   '>=1.3'
  spec.add_runtime_dependency 'redis',   '>=3.1'
  spec.add_runtime_dependency 'devnull', '~>0.1'
 
end
