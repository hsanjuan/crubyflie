# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'crubyflie/version'

Gem::Specification.new do |spec|
    spec.name          = "crubyflie"
    spec.version       = Crubyflie::VERSION
    spec.authors       = ["Hector Sanjuan"]
    spec.email         = ["hector@convivencial.org"]
    spec.description   = <<EOF
Client library to control a Crazyflie. This library allows to talk to a
crazyflie using the USB radio dongle.
EOF
    spec.summary       = "Crazyflie ruby client"
    spec.homepage      = ""
    spec.license       = "GPLv3"

    spec.files         = `git ls-files`.split($/)
    spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ["lib"]

    spec.add_dependency "libusb"

    spec.add_development_dependency "bundler", "~> 1.3"
    spec.add_development_dependency "rake"
    spec.add_development_dependency "rspec"
    spec.add_development_dependency "yard"
    spec.add_development_dependency "simplecov"
end
