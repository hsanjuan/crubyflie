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

require 'rubygems'
require 'yaml'
require 'sdl'

require 'input/input_reader'

module Crubyflie

    # Reads Joystick configuration and specific joystick input
    # See the default Joystick configuration file in the configs/
    # folder to have an idea what a configuration file looks like
    class Joystick < InputReader
        include Logging

        # Configuration type for Joystick configuration
        CONFIG_TYPE = "Joystick"
        # Default SDL joystick input range for axis
        DEFAULT_INPUT_RANGE = "-32768:32767"
        # Default Crazyflie min/max angles in degrees
        DEFAULT_OUTPUT_RANGE = "-30:30"
        # Default configuration file
        DEFAULT_CONFIG_PATH = File.join(File.dirname(__FILE__), "..","..","..",
                                        "configs", "joystick_default.yaml")
        
        attr_reader :config, :joystick_index
        # Initializes the Joystick configuration and the SDL library
        # leaving things ready to read values
        # @param config_path [String] path to configuration file
        # @param joystick_index [Integer] the index of the joystick in SDL
        def initialize(config_path=DEFAULT_CONFIG_PATH, joystick_index = 0)
            @config = nil
            @joystick_index = joystick_index
            @joystick = nil
            axis, buttons = read_configuration(config_path)
            super(axis, buttons)

        end

        # Closes the opened resources in SDL
        def quit
            SDL.quit()
        end

        # Parses a YAML Configuration files
        # @param path [String] Path to the file
        # @return [Array[Hash]] an array with axis and buttons and
        #                       and their associated action
        # @raise [JoystickException] on several configuration error cases
        def read_configuration(path)
            begin
                config_h = YAML.load_file(path)
            rescue
                raise JoystickException.new("Could load YAML: #{$!}")
            end

            if config_h[:type] != CONFIG_TYPE
                m = "Configuration is not of type #{CONFIG_TYPE}"
                raise JoystickException.new(m)
            end

            axis = {}
            if config_h[:axis].nil?
                raise JoystickException.new("No axis section")
            end
            config_h[:axis].each do |id, axis_cfg|
                action = axis_cfg[:action]
                if action.nil?
                    raise JoystickException.new("Axis #{id} needs an action")
                end

                axis[id] = action
            end

            buttons = {}
            if config_h[:buttons].nil?
                raise JoystickException.new("No buttons section")
            end
            config_h[:buttons].each do |id, button_cfg|
                action = button_cfg[:action]
                if action.nil?
                    raise JoystickException.new("Button #{id} needs an action")
                end
                buttons[id] = action
            end

            @config = config_h

            #logger.info "Loaded configuration correctly (#{path})"
            return axis, buttons
        end

        # Init SDL and open the joystick
        # @raise [JoystickException] if the joystick index is plainly wrong
        def init_sdl
            SDL.init(SDL::INIT_JOYSTICK)
            SDL::Joystick.poll = false
            n_joy = SDL::Joystick.num
            logger.info("Joysticks found: #{n_joy}")

            if @joystick_index >= n_joy
                raise JoystickException.new("No valid joystick index")
            end
            @joystick = SDL::Joystick.open(@joystick_index)
            name      = SDL::Joystick.index_name(@joystick_index)
            logger.info("Using Joystick: #{name}")
        end
        alias_method :init, :init_sdl

        # Used to read the current state of an axis. This is a rather
        # complicated operation. Raw value is first fit withing the input
        # range limits, then set to 0 if it falls in the dead zone,
        # then normalized to the output range that we will like to get (with
        # special case for thrust, as ranges have different limits), then
        # we check if the new value falls withing the change rate limit
        # and modify it if not, finally we re-normalize the thrust if needed
        # and return the reading, which should be good to be fit straight
        # into the Crazyflie commander.
        # @param axis_id [Integer] The SDL joystick axis to be read
        # @return [Fixnum, Float] the correctly-normalized-value from the axis
        def read_axis(axis_id)
            return 0 if !@joystick
            axis_conf = @config[:axis][axis_id]
            return 0 if axis_conf.nil?
            is_thrust = axis_conf[:action] == :thrust


            last_poll = axis_conf[:last_poll] || 0
            last_value = axis_conf[:last_value] || 0
            invert = axis_conf[:invert] || false
            calibration = axis_conf[:calibration] || 0

            input_range_s = axis_conf[:input_range] || DEFAULT_INPUT_RANGE
            ir_start, ir_end = input_range_s.split(':')
            input_range = Range.new(ir_start.to_i, ir_end.to_i)

            output_range_s = axis_conf[:output_range] || DEFAULT_OUTPUT_RANGE
            or_start, or_end = output_range_s.split(':')
            output_range = Range.new(or_start.to_i, or_end.to_i)

            # output value max jump per second. We covert to rate/ms
            max_chrate = axis_conf[:max_change_rate] || 10000
            max_chrate = max_chrate.to_f / 1000

            dead_zone = axis_conf[:dead_zone] || "0:0" # % deadzone around 0
            dz_start, dz_end = dead_zone.split(':')
            dead_zone_range = Range.new(dz_start.to_i, dz_end.to_i)

            value = @joystick.axis(axis_id)
            value *= -1 if invert
            value += calibration

            # Make sure input falls with the expected range
            if value > input_range.last then value = input_range.last end
            if value < input_range.first then value = input_range.first end
            # Dead zone

            if dead_zone_range.first < value && dead_zone_range.last > value
                value = 0
            end
            # Convert
            if is_thrust
                value = pre_normalize_thrust(value, input_range, output_range)
            else
                value = normalize(value, input_range, output_range)
            end

            # Check if we change too fast
            current_time = Time.now.to_f
            timespan = current_time - last_poll
            # How many ms have passed since last time
            timespan_ms = timespan.round(3) * 1000
            # How much have we changed/ms
            change = (value - last_value) / timespan_ms.to_f

            # Skip rate limitation if change is positive and this is thurst
            if !is_thrust || (is_thrust && change <= 0)
                # If the change rate exceeds  the max change rate per ms...
                if change.abs > max_chrate
                    # new value is the max change possible for the timespan
                    if change > 0
                        value = last_value + max_chrate * timespan_ms
                    elsif change < 0
                        value = last_value - max_chrate * timespan_ms
                    end
                end
            end

            if is_thrust
                value = normalize_thrust(value)
            end

            @config[:axis][axis_id][:last_poll] = current_time
            @config[:axis][axis_id][:last_value] = value

            return value
        end

        # The thrust axis is disabled for values < 0. What we do here is to
        # convert it to a thrust 0-100% value first and then make sure it
        # stays within the limits provided for output range
        def pre_normalize_thrust(value, input_range, output_range)
            value = normalize(value, input_range, (-100..100))
            value = 0 if value < 0
            if value > output_range.last then value = output_range.last
            elsif value < output_range.first then value = output_range.first
            end
            return value
        end
        private :pre_normalize_thrust


        # Returns integer from 10.000 to 60.000 which is what the crazyflie
        # expects
        def normalize_thrust(value)
            return normalize(value, (0..100), (10000..60000)).round
        end
        private :normalize_thrust

        # Reads the specified joystick button. Since we may want to calibrate
        # buttons etc, we return an integer
        # @param button_id [Integer] the SDL button number
        # @return [Fixnum] -1 if  the button is not pressed, 1 otherwise
        def read_button(button_id)
            return -1 if !@joystick
            return @joystick.button(button_id) ? 1 : -1
        end
        private :read_button

        # Called before reading
        def poll
            SDL::Joystick.update_all
        end
        private :poll

        # Linear-transforms a value in one range to a different range
        # @param value [Fixnum, Float] the value in the original range
        # @param from_range [Range] the range from which we want to normalize
        # @param to_range [Range] the destination range
        # @return [Float] the linear-corresponding value in the destination
        #                 range
        def normalize(value, from_range, to_range)
            from_width = from_range.size.to_f - 1
            to_width = to_range.size.to_f - 1
            from_min = from_range.first.to_f
            to_min = to_range.first.to_f
#            puts <<EOF
#"#{to_min}+(#{value.to_f}-#{from_min})*(#{to_width}/#{from_width})"
#EOF
            r = to_min + (value.to_f - from_min) * (to_width / from_width)
            return r.round(3)
        end
    end
end
