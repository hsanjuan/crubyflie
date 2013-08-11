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

module Crubyflie

    # This class provides functionality basic to all controllers.
    # Specific controller classes inherit from here.
    #
    # To read an input we must declare axis and buttons.
    # The axis are analog float readings (range decided by the
    # controller) while the buttons are integer where <= 0 means not pressed
    # and > 0 means pressed.
    #
    # The reading of the values is implemented by children classes.
    #
    # The InputReader will also apply the #INPUT_ACTIONS to a given
    # Crazyflie. In order to do that it will go through all the
    # read values and perform actioins associated to them, like sending
    # a setpoint or shutting down the connection or altering the calibration.
    class InputReader

        # List of current recognized actions that controllers can declare
        INPUT_ACTIONS = [:roll, :pitch, :yaw, :thrust,
                         :roll_inc_cal, :roll_dec_cal,
                         :pitch_inc_cal, :pitch_dec_cal,
                         :switch_xmode,  :close_link]

        attr_reader :axis, :buttons, :axis_readings, :button_readings
        attr_accessor :xmode
        # An input is composed by several necessary axis, buttons and
        # calibrations.
        # @param axis [Hash] A hash of keys identifying axis IDs
        #                    (the controller should know to what the
        #                     ID maps, and values from #INPUT_ACTIONS
        # @param buttons [Hash] A hash of keys identifying button IDs (the
        #                    controller should know to what the ID maps,
        #                    and values from #INPUT_ACTIONS
        def initialize(axis, buttons)
            @axis = axis
            @buttons = buttons
            @calibrations = {}
            @xmode = false

            # Calibrate defaults to 0
            INPUT_ACTIONS.each do |action|
                @calibrations[action] = 0
            end

            @axis_readings = {}
            @button_readings = {}
        end

        # Read inputs will call read_axis() on all the declared axis
        # and read_button() on all the declared buttons.
        # After obtaining the reading, it will apply calibrations to
        # the result. Apply the read values with #apply_input
        def read_input
            poll() # In case we need to poll the device
            actions_to_axis = @axis.invert()
            actions_to_axis.each do |action, axis_id|
                @axis_readings[action] = read_axis(axis_id)
                @axis_readings[action] += @calibrations[action]
            end

            actions_to_buttons = @buttons.invert()
            actions_to_buttons.each do |action, button_id|
                @button_readings[action] = read_button(button_id)
                @button_readings[action] += @calibrations[action]
            end
        end

        # This will act on current axis readings (by sendint a setpoint to
        # the crazyflie) and on button readings (by, for example, shutting
        # down the link or modifying the calibrations.
        # If the link to the crazyflie is down, it will not send anything.
        # @param crazyflie [Crazyflie] A crazyflie instance to send the
        #                              setpoint to.
        def apply_input(crazyflie)
            return if !crazyflie.active?
            setpoint = {
                :roll => nil,
                :pitch => nil,
                :yaw => nil,
                :thrust => nil
            }

            @button_readings.each do |action, value|
                case action
                when :roll
                    setpoint[:roll] = value
                when :pitch
                    setpoint[:pitch] = value
                when :yaw
                    setpoint[:yaw] = value
                when :thrust
                    setpoint[:thrust] = value
                when :roll_inc_cal
                    @calibrations[:roll] += 1
                when :roll_dec_cal
                    @calibrations[:roll] -= 1
                when :pitch_inc_cal
                    @calibrations[:pitch] += 1
                when :pitch_dec_cal
                    @calibrations[:pitch] -= 1
                when :switch_xmode
                    @xmode = !@xmode if value > 0
                    logger.info("Xmode is #{@xmode}") if value > 0
                when :close_link
                    crazyflie.close_link() if value > 0
                end
            end

            return if !crazyflie.active?

            @axis_readings.each do |action, value|
                case action
                when :roll
                    setpoint[:roll] = value
                when :pitch
                    setpoint[:pitch] = value
                when :yaw
                    setpoint[:yaw] = value
                when :thrust
                    setpoint[:thrust] = value
                end
            end

            pitch  = setpoint[:pitch]
            roll   = setpoint[:roll]
            yaw    = setpoint[:yaw]
            thrust = setpoint[:thrust]

            if pitch && roll && yaw && thrust
                m = "Sending R: #{roll} P: #{pitch} Y: #{yaw} T: #{thrust}"
                #logger.debug(m)
                crazyflie.commander.send_setpoint(roll, pitch, yaw, thrust,
                                                  @xmode)
            end
        end

        private
        def read_axis(axis_id)
            raise Exception.new("Not implemented!")
        end

        def read_button(button_id)
            raise Exception.new("Not implemented!")
        end

        def poll
        end
    end
end
