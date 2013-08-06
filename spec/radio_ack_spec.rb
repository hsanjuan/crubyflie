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

require 'crazyradio/radio_ack'

describe RadioAck do
    describe "#initialize" do
        it "should initialize a RadioAck" do
            rack = RadioAck.new(true, 1, 5, [1,2,3])
            rack.ack.should == true
            rack.powerDet.should == 1
            rack.retry_count.should == 5
            rack.data.should == [1,2,3]
        end
    end
    describe "#from_raw" do
        it "should create a radio ack from raw USB data" do
            header = 0b11110101 # ack = 1, powerDet = 0, retry_c = 1111
            data = [0xFF] * 31
            packet = [header].concat(data)
            rack = RadioAck.from_raw(packet.pack('C*'))
            rack.ack.should == true
            rack.powerDet.should == false
            rack.retry_count.should == 15
            rack.data == data
        end
    end
end
