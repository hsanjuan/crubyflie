#!/usr/bin/env ruby
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

# Require the Crubyflie gem
require 'crubyflie'
include Crubyflie # easy to use things in namespace

# Create a new Crazyflie with cache folder "cache"
cf = Crazyflie.new('cache')
# Before opening any link, scan for interfaces
ifaces = cf.scan_interface
if ifaces.empty?
    logger.error("No crazyflies found")
    exit 1
end
logger.info("Found interfaces: #{ifaces}")

# Open a link to the first interface
cf.open_link(ifaces.first)
# Make sure everything is still good
exit 1 if !cf.active?

# Write the TOCs to stdout
puts "Log TOC"
puts cf.log.toc.to_s
puts
puts "Param TOC"
puts cf.param.toc.to_s

# Read some parameters
puts "--------"
cf.param.get_value("attitudepid.kp_pitch") do |value|
    puts "kp_pitch: #{value}"
end
cf.param.get_value("attitudepid.ki_pitch") do |value|
    puts "ki_pitch: #{value}"
end
cf.param.get_value("attitudepid.kd_pitch") do |value|
    puts "kd_pitch: #{value}"
end
puts "--------"


# We use 1 variable, is_toc = true
# The last two 7 means it is stored and fetched as float
log_conf_var = LogConfVariable.new("stabilizer.pitch", true, 7, 7)

# We create a configuration object
# We want to fetch it every 0.1 secs
log_conf = LogConf.new([log_conf_var], {:period => 10})

# With the configuration object, register a log_block
block_id = cf.log.create_log_block(log_conf)

# Start logging
# Counter on how many times we have logged the pitch
logged = 0
cf.log.start_logging(block_id) do |data|
    warn "Pitch: #{data['stabilizer.pitch']}"
    logged += 1
end

# Wait until we have hit the log_cb 10 times
while (logged < 10)
    sleep 1
end

# Stop logging
cf.log.stop_logging(block_id)

# After finishing, close the link!
cf.close_link()
