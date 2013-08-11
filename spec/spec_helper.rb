# -*- coding: utf-8 -*-
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

require 'simplecov'
SimpleCov.at_exit do
    SimpleCov.minimum_coverage 95
    SimpleCov.result.format!
end
SimpleCov.start do
    add_group "Libraries", "lib"
    add_group "Specs", "spec"
end


$: << File.join(File.dirname(__FILE__), "lib")
$: << File.join(File.dirname(__FILE__))

require 'crubyflie'
include Crubyflie
include CRTPConstants

require 'radio_ack_spec'
require 'crtp_packet_spec'
require 'crazyradio_spec'
require 'radio_driver_spec'
require 'radio_ack_spec'
require 'toc_cache_spec'
require 'toc_spec'
require 'crazyflie_spec'
require 'log_spec'
require 'param_spec'
require 'console_spec'
require 'commander_spec'
require 'joystick_input_reader_spec'
require 'input_reader_spec'
require 'crubyflie_logger_spec'
