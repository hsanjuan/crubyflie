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

require 'crazyflie'


describe Crazyflie do
    before :each do
        @resource = double("Resource")
        allow(Commander).to receive(:new).and_return(@resource)
        allow(Param).to receive(:new).and_return(@resource)
        allow(Log).to receive(:new).and_return(@resource)
        allow(Commander).to receive(:new).and_return(@resource)
        allow(@resource).to receive(:send_setpoint)
        allow(@resource).to receive(:refresh_toc)
        @link = double("RadioDriver")
        @uri = 'radio://0/0/1M'
        allow(RadioDriver).to receive(:new).and_return(@link)
        allow(@link).to receive(:connect)
        allow(@link).to receive(:disconnect)
        allow(@link).to receive(:receive_packet)
        allow(@link).to receive(:uri).and_return(URI(@uri))
        @cf = Crazyflie.new()
        allow(@cf).to receive(:puts)
        allow(@cf).to receive(:warn)

        @default_pk = CRTPPacket.new(0b00001100, [1,2,3])
    end


    describe "#initialize" do
        it "should initalize correctly" do
            Crazyflie::CALLBACKS.each do |cb|
                @cf.callbacks[cb].size.should >= 0
            end

            Crazyflie::CRTP_PORTS.keys().each do |port|
                @cf.crtp_queues[port].should be_an_instance_of Queue
            end
        end
    end


    describe "#open_link" do
        it "should connect to a crazyradio url" do
            allow(@link).to receive(:receive_packet).and_return(@default_pk)
            m = "Connection initiated to radio://0/0/1M"
            expect(@cf).to receive(:puts).with(m)
            expect(@cf).to receive(:puts).with("Connected!")
            expect(@cf).to receive(:puts).with("TOCs extracted from #{@uri}")
            allow(@resource).to receive(:refresh_toc)
            expect(@resource).to receive(:refresh_toc).twice
            @cf.open_link(@uri)
            @cf.close_link()
        end

        it "should close the link if something happens" do
            allow(@link).to receive(:connect).and_raise(Exception)
            expect(@cf).to receive(:puts).with("Connection failed Exception")
            expect(@resource).not_to receive(:refresh_toc)
            @cf.open_link(@uri)
            @cf.close_link()
        end
    end

    describe "#close_link" do
        it "should close the link and kill the thread" do
            allow(@resource).to receive(:send_setpoint)
            expect(@resource).to receive(:send_setpoint)
            expect(@link).to receive(:disconnect)
            m = "Disconnected from radio://0/0/1M"
            expect(@cf).to receive(:puts).with(m)
            expect_any_instance_of(Thread).to receive(:kill).once

            @cf.open_link(@uri)
            @cf.close_link()
        end

        it "should not break closing a non existing link" do
            expect(@resource).not_to receive(:send_setpoint)
            expect_any_instance_of(NilClass).not_to receive(:disconnect)
            expect(@cf).not_to receive(:puts)
            expect_any_instance_of(Thread).not_to receive(:kill)
            @cf.close_link()
        end
    end

    describe "#send_packet" do
        it "should send a packet without expecting answer" do
            expect(@cf).not_to receive(:setup_retry)
            expect(@link).to receive(:send_packet).with(@default_pk)
            @cf.open_link(@uri)
            @cf.send_packet(@default_pk)
            @cf.close_link()
        end

        it "should send a packet and set up a timer when expecting answer" do
            pk = @default_pk
            expect(@link).to receive(:send_packet).with(pk).at_least(:twice)
            @cf.open_link(@uri)
            @cf.send_packet(@default_pk, true)
            sleep 0.2
            @cf.close_link()
        end
    end

    describe "#receive_packet" do
        it " should receive a packet, trigger callbacks" do
            proc = Proc.new do
                puts "port 0 ch 0 callback"
            end

            proc2 = Proc.new do |pk|
                puts "Received packet"
            end

            @cf.callbacks[:received_packet][:log] = proc
            @cf.callbacks[:received_packet][:log2] = proc2

            allow_any_instance_of(Thread).to receive(:new).and_return(nil)
            allow(@link).to receive(:receive_packet).and_return(@default_pk)
            expect(proc).to receive(:call).with(@default_pk).at_least(:once)
            expect(proc2).to receive(:call).with(@default_pk).at_least(:once)
            expect(@cf.crtp_queues[:console]).to receive(:<<).once
            @cf.open_link(@uri)
            @cf.send(:receive_packet)
            # Received packet comes on port 0 - console

            @cf.close_link()
        end
    end
end
