# -*- coding: utf-8 -*-
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

module Crubyflie
    # An acknowlegdement packet from the Crazyflie
    class RadioAck
        attr_accessor :ack, :powerDet, :retry_count, :data

        # Initialize a Radio Ack
        # @param ack [TrueClass,FalseClass] indicates if it is an ack
        # @param powerDet [TrueClass,FalseClass] powerDet
        # @param retry_count [Integer] the times we retried to send the packet
        # @param data [Array] the payload of the ack packet
        def initialize(ack=nil, powerDet=nil, retry_count=0, data=[])
            @ack = ack
            @powerDet = powerDet
            @retry_count = retry_count
            @data = data
        end

        # Create from raw usb response
        # @param data [String] binary data
        # @return [RadioAck] a properly initialized RadioAck
        def self.from_raw(data, arc=0)
            response = data.unpack('C*')
            header = response.shift()
            ack = (header & 0x01) != 0
            powerDet = (header & 0x02) != 0
            retry_count = header != 0 ? header >> 4 : arc
            return RadioAck.new(ack, powerDet, retry_count, response)
        end
    end
end
