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

$: << File.join(File.dirname(__FILE__), 'crubyflie')

require 'crubyflie_logger'
require 'crazyflie'
require 'input/joystick_input_reader'
require 'version'

# The Crubyflie modules wraps all the Crubyflie code so we don't
# pollute the namespace.
module Crubyflie
    $debug = false
    include Logging
end
