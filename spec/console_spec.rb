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

require 'crazyflie/console'

describe Console do
    before :each do
        @crazyflie = double("Crazyflie")
        @queue = Queue.new
        allow(@crazyflie).to receive(:crtp_queues).and_return({:console =>
                                                                  @queue})

        @console = Console.new(@crazyflie)
    end
    describe "#initialize" do
        it "should intialize the facility" do
            c = Console.new(@crazyflie)
            expect_any_instance_of(Thread).not_to receive(:new)
        end
    end

    describe "#read" do
        it "should read all packets available from the queue" do
            count = 1
            p1 = CRTPPacket.new()
            p1.data = "baa1".unpack('C*')
            p2 = CRTPPacket.new()
            p2.data = "baa2".unpack('C*')

            @queue << p1
            @queue << p2

            @console.read do |message|
                message.should == "baa#{count}"
                count += 1
            end
            @queue.size.should == 0
        end
    end

    describe "#start_reading" do
        it "should read continuously" do
            count = 1
            p1 = CRTPPacket.new()
            p1.data = "baa1".unpack('C*')
            p2 = CRTPPacket.new()
            p2.data = "baa2".unpack('C*')

            @queue << p1
            @queue << p2

            @console.start_reading do |message|
                message.should == "baa#{count}"
                count += 1
            end
            sleep 0.3
            @queue.size.should == 0
            @console.stop_reading()
        end
    end
end
