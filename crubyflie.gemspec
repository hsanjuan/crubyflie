# coding: utf-8
# Copyright (C) 2013 Hector Sanjuan

# This file is part of Crubyflie.

# Crubyflie is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Crubyflie is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Crubyflie.  If not, see <http://www.gnu.org/licenses/>

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
    spec.homepage      = "https://github.com/hsanjuan/crubyflie"
    spec.license       = "GPLv3"

    spec.files         = `git ls-files`.split($/)
    spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
    spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
    spec.require_paths = ["lib"]

    spec.add_dependency "libusb"
    spec.add_dependency "rubysdl"
    spec.add_dependency "trollop"

    spec.add_development_dependency "bundler", "~> 1.3"
    spec.add_development_dependency "rake"
    spec.add_development_dependency "rspec"
    spec.add_development_dependency "yard"
    spec.add_development_dependency "simplecov"
    spec.add_development_dependency "coveralls"
end
