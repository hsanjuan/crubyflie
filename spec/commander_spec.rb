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

require 'crazyflie/commander'

describe Commander do

    before :each do
        @crazyflie = double("Crazyflie")
        @queue = Queue.new
        allow(@crazyflie).to receive(:crtp_queues).and_return({:commander =>
                                                                  @queue})

        @commander = Commander.new(@crazyflie)
    end

    describe "#initialize" do
        it "should initialize the facility" do
            c = Commander.new(@crazyflie)
            c.xmode.should == false
            c.xmode = true
            c.xmode.should == true
        end
    end

    describe "#send_sendpoint" do
        it "should send a sendpoint in normal mode" do
            expect(@crazyflie).to receive(:send_packet) do |packet, want_answer|
                want_answer.should == false
                packet.port.should == Crazyflie::CRTP_PORTS[:commander]
                packet.channel.should == 0
                packet.data.size.should == 14
                packet.data_repack.unpack('eeeS<').should == [1,-2,3,6]
            end

            @commander.send_setpoint(1,2,3,6)
        end

        it "should send a sendpoint in xmode" do
            expect(@crazyflie).to receive(:send_packet) do |packet, want_answer|
                want_answer.should == false
                packet.port.should == Crazyflie::CRTP_PORTS[:commander]
                packet.channel.should == 0
                packet.data.size.should == 14
                data = packet.data_repack.unpack('eeeS<')
                data[0].round(3).should == -0.707
                data[1].round(4).should == -0.9142
                data[2].should == 3.0
                data[3].should == 6
            end

            @commander.xmode = true
            @commander.send_setpoint(1,2,3,6)
        end
    end
end
