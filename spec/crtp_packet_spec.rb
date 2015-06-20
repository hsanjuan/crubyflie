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

require 'driver/crtp_packet'

describe CRTPPacket do
    describe "#initalize" do
        it "should initialize correctly a packet" do
            header = 0b11101010 # channel 10; port 1110
            payload = [1,2,3]
            packet = CRTPPacket.new(header, payload)
            packet.size.should == 3
            packet.header.should == header
            packet.data.should == payload
            packet.channel.should == 0b10
            packet.port.should == 0b1110
        end
    end

    describe "#modify_header" do
        it "should modify only with header if provided" do
            header = 0b11101010 # channel 10; port 1110
            payload = [1,2,3]
            packet = CRTPPacket.new(header, payload)
            packet.modify_header(0, 3, 4)
            packet.header.should == 0
            packet.channel.should == 0
            packet.port.should == 0
        end

        it "should modify channel and port and set the header" do
            channel = 0b10
            port = 0b1101
            payload = [1,2,3]
            packet = CRTPPacket.new(0, payload)
            packet.modify_header(nil, port, channel)
            packet.header.should == 0b11010010
            packet.channel.should == 0b10
            packet.port.should == 0b1101
        end
    end

    describe "#unpack" do
        it "should return an empty package if data is empty or not array" do
            CRTPPacket.unpack("abc").pack.should == [0b00001100]
            CRTPPacket.unpack([]).pack.should == [0b00001100]
        end

        it "should unpack a data array correctly into header and data" do
            packet = CRTPPacket.unpack([1,2,3])
            packet.data.should == [2,3]
            packet.header.should == 0b00000001
        end
    end

    describe "#pack" do
        it "should concat header and data" do
            header = 0b11101010 # channel 10; port 1110
            payload = [1,2,3]
            packet = CRTPPacket.new(header, payload)
            packet.pack.should == [0b11101110, 1, 2, 3]
        end
    end
end
