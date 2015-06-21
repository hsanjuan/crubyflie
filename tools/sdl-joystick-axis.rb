#!/usr/bin/env ruby
# Copyright (C) 2015 Hector Sanjuan

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

require 'sdl'
require 'pp'

warn "Welcome to Crubyflie joystick utility. Ctrl-C to exit."
warn "--"
Signal.trap("SIGINT") do
    warn "\n\n"
    warn "Bye bye!"
    SDL.quit
    exit 0
end

SDL.init(SDL::INIT_JOYSTICK)
n_joy = SDL::Joystick.num
if n_joy == 0
    warn "No joysticks found"
    exit 1
end


warn "Total number of Joysticks: #{n_joy}"
n_joy.times do |i|
    warn "#{i}: #{SDL::Joystick.index_name(i)}"
end
warn "--"
print "Which one should we use (0-#{n_joy-1}): "
joy_id = gets.to_i
joy = SDL::Joystick.open(joy_id)
warn "Opened Joystick #{joy_id}"
warn "Name: SDL::Joystick.index_name(#{joy_id})"
warn "Number of Axes: #{joy.num_axes}"
warn "Number of buttons: #{joy.num_buttons}"
warn "Here is the reading for axis and buttons:"
loop {
    SDL::Joystick.update_all
    joy.num_axes.times do |i|
        print "A##{i}: #{joy.axis(i)} | "
    end

    print " || "

    button_read = []
    joy.num_buttons.times do |i|
        print "B##{i}: #{joy.button(i) ? 1 : 0} | "
    end
    print "\r"
    $stdout.flush
    sleep 0.05
}
