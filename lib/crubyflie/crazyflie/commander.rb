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
    # The Commander facility is used to send control information to the
    # Crazyflie. You want to use this class to fly your Crazyflie
    class Commander
        # Initialize the facility
        attr_accessor :xmode
        def initialize(crazyflie)
            @crazyflie = crazyflie
            @xmode = false
        end

        # Send a setpoint to the Crazyflie
        #
        # The roll, pitch, yaw values are floats with positive or negative
        # values. The range should be the value read from the controller
        # ([-1,1]) multiplied by the maximum angle change rate
        # @param roll [float] the roll value
        # @param pitch [float] the pitch value
        # @param yaw [float] the yaw value
        # @param thrust [Integer] thrust is an integer value ranging
        #                         from 10001 (next to no power) to
        #                         60000 (full power)
        def send_setpoint(roll, pitch, yaw, thrust)
            if @xmode
                roll = 0.707 * (roll - pitch)
                pitch = 0.707 * (roll + pitch)
            end

            packet = CRTPPacket.new()
            packet.modify_header(nil, Crazyflie::CRTP_PORTS[:commander], nil)
            data = [roll, -pitch, yaw, thrust]
            # send 3 floats and one unsigned short (16 bits) (all little endian)
            data = data.pack('eeeS<')
            packet.data = data.unpack('C*')
            @crazyflie.send_packet(packet, false)
        end
    end
end
