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

# A simple script to list SDL axis/button numbering and read values

# This module is included where needed and offers
# easy access to the logger
module Logging
    # Give me a logger
    # @return [CrubyflieLogger]
    def self.logger
        Logging.logger
    end

    # Lazy initialization for a logger
    # @return [CrubyflieLogger]
    def logger
        @logger ||= CrubyflieLogger.new()
    end

    # Set a logger
    # @param logger [CrubyflieLogger] the new logger to use
    def logger=(logger)
        @logger = logger
    end
end

# A simple logger to log debug messages, info, warnings and errors
class CrubyflieLogger
    # Initialize a logger and enable debug logs
    # @param debug [TrueClass,nil] enable output of debug messages
    def initialize(debug=$debug)
        @@debug = debug
    end

    # Logs a debug message
    # @param msg [String] the message to be logged
    def debug(msg)
        $stderr.puts "DEBUG: #{msg}" if @@debug
    end

    # Logs an info message to $stdout
    # @param msg [String] the message to be logged
    def info(msg)
        $stdout.puts "INFO: #{msg}"
    end

    # Logs a warning message to $stderr
    # @param msg [String] the message to be logged
    def warn(msg)
        $stderr.puts "WARNING: #{msg}"
    end

    # Logs an error message to $stderr
    # @param msg [String] the message to be logged
    def error(msg)
        $stderr.puts "ERROR: #{msg}"
    end
end
