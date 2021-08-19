lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nebulous_stomp/version'

Gem::Specification.new do |spec|
  spec.name          = "nebulous_stomp"
  spec.version       = NebulousStomp::VERSION
  spec.authors       = ["Andy Jones"]
  spec.email         = ["andy.jones@twosticksconsulting.co.uk"]
  spec.summary       = %q{Handles request-and-response messaging via STOMP}
  spec.description   = <<-DESC.gsub(/^\s+/, "")
    A library and protocol to allow disperate systems to ask a question via
    STOMP and receive an answer in return. Optionally, answers can be cached in
    Redis.
  DESC

  spec.license       = "MIT"
  spec.homepage      = "https://bitbucket.org/andy-twosticks/nebulous_stomp"

  spec.files         = `hg status -macn0`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.extra_rdoc_files = spec.files.grep(%r{^md/})

  spec.requirements << 'STOMP Messaging server'
  spec.requirements << 'Redis server (optional)'

  spec.post_install_message = <<-MESSAGE.gsub(/^\s+/, "")
    Nebulous has been installed ...sort of... ::waves arms noncomittedly::
  MESSAGE

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake",    "~> 13.0"
  spec.add_development_dependency "rspec",   "~> 3.10"
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "ripper-tags"

  # Note, Stomp 1.4.5 does not work with jRuby; see https://github.com/stompgem/stomp/issues/153
  #spec.add_runtime_dependency 'stomp',   '1.4.8'
  spec.add_runtime_dependency 'stomp',   '1.4.10'
  
  # Note this is very much not the latest version, we need to fix this
  spec.add_runtime_dependency 'redis',   '~>3.3'
  spec.add_runtime_dependency 'devnull', '~>0.1'
 
end
