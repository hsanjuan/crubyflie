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

require 'driver/radio_driver'

describe RadioDriver do
    before :each do
        @radiodriver = RadioDriver.new()
        @link_error_cb = Proc.new {|m| m}
        @link_quality_cb = Proc.new {|m| m}
        @connect_params = ['radio://0/2/1M',{
                               :link_quality_cb => @link_quality_cb,
                               :link_error_cb   => @link_error_cb
                           }]
        @crazyradio = double("Crazyradio")
        allow(@crazyradio).to receive(:close)
        @ack = RadioAck.new(true, true, 3, [1,2,3])
        allow(@crazyradio).to receive(:send_packet).and_return(@ack)
        allow(Crazyradio).to receive(:new).and_return(@crazyradio)

    end

    describe "#initialize" do
        it "should intialize the radio driver" do
            rd = RadioDriver.new()
            rd.should be_an_instance_of RadioDriver
            rd.uri.should be_nil
        end
    end

    describe "#connect" do
        it "should connect" do
            expect(@radiodriver).to receive(:start_radio_thread)

            @radiodriver.connect(*@connect_params)

            expected_retries = RadioDriver::RETRIES_BEFORE_DISCONNECT
            expected_queue_size = RadioDriver::OUT_QUEUE_MAX_SIZE
            @radiodriver.retries_before_disconnect.should == expected_retries
            @radiodriver.out_queue_max_size.should == expected_queue_size
            @radiodriver.disconnect()
        end


        it "should raise an exception if the link is active" do
            @radiodriver.connect(*@connect_params)
            mesg = "Active link to radio://0/2/1M. Disconnect first"
            expect {
                @radiodriver.connect('radio://1/2/2M')
            }.to raise_exception(OpenLink, mesg)
            @radiodriver.disconnect()
        end

        it "should raise an exception a callback is missing" do
            expect {
                @radiodriver.connect('radio://1/2/2M', {
                                         :link_quality_cb => Proc.new {}
                                     })
            }.to raise_exception(CallbackMissing,
                                 "Callback link_error_cb mandatory")
        end
    end

    describe "#disconnect" do
        it "should disconnect if it is not connected" do
            expect(@crazyradio).not_to receive(:close)
            @radiodriver.disconnect()
        end

        it "should disconnect if it is connected" do
            expect(@crazyradio).to receive(:close)
            @radiodriver.connect(*@connect_params)
            @radiodriver.disconnect()
        end

        it "should kill the thread if disconnect is called with true" do
            expect_any_instance_of(Thread).to receive(:kill)
            @radiodriver.connect(*@connect_params)
            @radiodriver.disconnect(true)
        end
    end

    describe "#send_packet" do
        it "should do nothing when not connected" do
            #expect_any_instance_of(Queue).not_to receive(:push)
            @radiodriver.send_packet([1,2,3])
        end

        it "should push a packet to the queue and send it" do
            #expect_any_instance_of(Queue).to receive(:push)
            expect(@crazyradio).to receive(:send_packet)
            @radiodriver.connect(*@connect_params)
            @radiodriver.send_packet(CRTPPacket.unpack([1,2,3]))
            @radiodriver.disconnect()
        end

        it "should call the link error callback if max size is reached" do
            # prevent consuming packages
            expect(@radiodriver).to receive(:start_radio_thread)
            @radiodriver.connect(*@connect_params)
            max = @radiodriver.out_queue_max_size
            m = "Reached #{max} elements in outgoing queue"
            expect(@link_error_cb).to receive(:call).with(m).twice
            (1..52).each do
                @radiodriver.send_packet([4,5,6])
            end
            @radiodriver.disconnect()
        end
    end

    describe "#receive_packet" do
        # note that thread sends control packages all the time
        it "should receive nil if queue is empty" do
            @radiodriver.connect(*@connect_params)
            @radiodriver.disconnect() #empty queues
            @radiodriver.receive_packet(true).should be_nil
        end

        it "should raise error if Crazyradio complains" do
            e = USBDongleException
            expect(@crazyradio).to receive(:send_packet).and_raise(e, "aa")
            m = "Error communicating with Crazyradio: aa"
            expect(@link_error_cb).to receive(:call).with(m)
            @radiodriver.connect(*@connect_params)
            @radiodriver.disconnect()
        end

        it "should raise error if nil is returned as response" do
            allow(@crazyradio).to receive(:send_packet).and_return(nil)
            m = "Dongle communication error (ack is nil)"
            expect(@link_error_cb).to receive(:call).with(m)
            @radiodriver.connect(*@connect_params)
            @radiodriver.disconnect()
        end

        it "should suicide if too many packets are lost" do
            allow(@ack).to receive(:ack).and_return(false)
            m = "Too many packets lost"
            expect(@link_error_cb).to receive(:call).with(m).once
            @radiodriver.connect(*@connect_params)
            @radiodriver.disconnect()
        end

        it "should receive a packet" do
            expect(@link_quality_cb).to receive(:call).with(3).at_least(:once)
            @radiodriver.connect(*@connect_params)
            @radiodriver.send_packet(CRTPPacket.unpack([1,2,3]))
            packet = @radiodriver.receive_packet(false)
            # send package returns an ack with [1,2,3] as data
            expect(packet).to be_an_instance_of CRTPPacket
            packet.size.should == 2
            packet.header.should == 1
            packet.data.should == [2,3]
            @radiodriver.disconnect()
        end
    end

    describe "#scan_interface" do
        it "should complain if link is open" do
            @radiodriver.connect(*@connect_params)
            expect {
                @radiodriver.scan_interface()
            }.to raise_exception(OpenLink, "Cannot scan when link is open")
            @radiodriver.disconnect()
        end

        it "should return the found some uris" do
            allow(@crazyradio).to receive(:scan_channels).and_return([1,2,3],
                                                                     [7,8,9],
                                                                     [21,22,4])
            expect(@crazyradio).to receive(:[]=).with(:arc, 1)
            expect(@crazyradio).to receive(:[]=).with(:data_rate,
                                                      Crazyradio::DR_250KPS)
            expect(@crazyradio).to receive(:[]=).with(:data_rate,
                                                      Crazyradio::DR_1MPS)
            expect(@crazyradio).to receive(:[]=).with(:data_rate,
                                                      Crazyradio::DR_2MPS)
            expect(@crazyradio).to receive(:close)
            @radiodriver.scan_interface().should == [
                                                     'radio://0/1/250K',
                                                     'radio://0/2/250K',
                                                     'radio://0/3/250K',
                                                     'radio://0/7/1M',
                                                     'radio://0/8/1M',
                                                     'radio://0/9/1M',
                                                     'radio://0/21/2M',
                                                     'radio://0/22/2M',
                                                     'radio://0/4/2M']
        end

        it "should return an empty list if a usb dongle exception happens" do
            e = USBDongleException
            allow(@crazyradio).to receive(:scan_channels).and_raise(e)
            allow(@crazyradio).to receive(:[]=)
            @radiodriver.scan_interface().should == []
        end
    end

    describe "#get_status" do
        it "should get status" do
            allow(Crazyradio).to receive(:status).and_return("hola")
            @radiodriver.get_status.should == "hola"
        end
    end
end
