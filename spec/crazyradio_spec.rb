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

require 'crazyradio/crazyradio'

describe Crazyradio do
    before :each do
        @device = double("LIBUSB::Device")
        @handle = double("LIBUSB::DevHandler")

        allow(@device).to receive(:is_a?).and_return(LIBUSB::Device)
        allow(@device).to receive(:open).and_return(@handle)
        allow(@device).to receive(:serial_number).and_return("serial123")
        allow(@device).to receive(:manufacturer).and_return("Bitcraze")
        allow(@handle).to receive(:configuration=)
        allow(@handle).to receive(:claim_interface)
        tr_result = [1,2,3].pack('C*')
        allow(@handle).to receive(:control_transfer).and_return(tr_result)
        allow(@handle).to receive(:release_interface)
        allow(@handle).to receive(:reset_device)
        allow(@handle).to receive(:close)

        @crazyradio = Crazyradio.new(@device)
    end

    describe "#initialize" do
        it "should initialize the dongle correctly" do
            settings = [:data_rate, :channel, :cont_carrier,
             :address, :power, :arc, :ard_bytes]
            ssize = settings.size
            expect(@device).to receive(:open)
            expect(@handle).to receive(:configuration=).with(1)
            expect(@handle).to receive(:claim_interface).with(0)
            expect(@handle).to receive(:control_transfer).exactly(ssize).times
            crazyradio = Crazyradio.new(@device)
            defaults = Crazyradio::DEFAULT_SETTINGS
            settings.each do |setting|
                crazyradio[setting].should == defaults[setting]
            end
        end

        it "should not initialize with a nil device" do
            expect { Crazyradio.new() }.to raise_error(USBDongleException,
                                                       "Wrong USB device")
        end
    end

    describe "#status" do
        it "should return a status" do
            allow(Crazyradio).to receive(:factory).and_return(@crazyradio)
            status = "Found serial123 USB dongle from Bitcraze"
            Crazyradio.status().should == status
        end
    end

    describe "#close" do
        it "should close the USB" do
            expect(@handle).to receive(:release_interface).with(0)
            expect(@handle).to receive(:reset_device)
            expect(@handle).to receive(:close)
            @crazyradio.close()
            @crazyradio.device.should be_nil
        end
    end

    describe "#has_fw_scan" do
        it "should say false" do
            @crazyradio.has_fw_scan.should be_false
        end
    end

    describe "#scan_channels" do
        it "should scan channels and return them" do
            ack = RadioAck.new(true)
            do_this = receive(:send_packet).with([0xFF]).and_return(ack)
            allow(@crazyradio).to do_this
            @crazyradio.scan_channels(0, 125).should == (0..125).to_a
        end

        it "should scan channels with fw_scan and return them" do
            allow(@crazyradio).to receive(:has_fw_scan).and_return(true)
            @crazyradio.scan_channels(0, 125).should == [1,2,3]
        end

        it "should not include bad channels in a scan" do
            ack = RadioAck.new(false)
            do_this = receive(:send_packet).with([0xFF]).and_return(ack)
            allow(@crazyradio).to do_this
            @crazyradio.scan_channels(0, 125).should == []
        end
    end

    describe "#factory" do
        it "should raise an exception if no dongles are found" do
            do_this = receive(:devices).and_return([])
            allow_any_instance_of(LIBUSB::Context).to do_this

            expect { Crazyradio.factory() }.to raise_error(USBDongleException,
                                                           "No dongles found")
        end

        it "should provide a new crazyradio item" do
            do_this = receive(:devices).and_return([@device])
            allow_any_instance_of(LIBUSB::Context).to do_this
            Crazyradio.factory()
        end
    end

    describe "#send_packet" do
        it "should send a packet and get a response" do
            dataout = { :endpoint => 1, :dataOut => [1,2,3,4,5].pack('C*')}
            datain = { :endpoint => 0x81, :dataIn => 64}
            response = ([0xFF] * 64).pack('C*')
            do_this =  receive(:bulk_transfer)
            expect(@handle).to do_this.with(dataout).and_return(response)
            expect(@handle).to do_this.with(datain).and_return(response)

            ack = @crazyradio.send_packet([1,2,3,4,5])
            ack.should be_an_instance_of RadioAck
            ack.ack.should == true
            ack.data.should == [0xFF] * 63
        end
    end

    describe "#[]=" do
        it "should set a setting" do
            expect(@crazyradio).to receive(:set_data_rate).with(58)
            @crazyradio[:data_rate] = 58
        end
        it "should no set a bad setting" do
            expect(@crazyradio).not_to receive(:set_data_rate)
            expect(@crazyradio).not_to receive(:set_channel)
            expect(@crazyradio).not_to receive(:set_arc)
            expect(@crazyradio).not_to receive(:set_cont_carrier)
            expect(@crazyradio).not_to receive(:set_address)
            expect(@crazyradio).not_to receive(:set_power)
            expect(@crazyradio).not_to receive(:set_ard_bytes)
            @crazyradio[:abc] = 3
            @crazyradio[:abc].should be_nil
        end
    end

    describe "[]" do
        it "should get a setting value" do
            expected = Crazyradio::DEFAULT_SETTINGS[:channel]
            @crazyradio[:channel].should == expected
        end
    end

    describe "#apply_settings" do
        it "should apply one setting" do
            d = Crazyradio::DEFAULT_SETTINGS
            expect(@crazyradio).to receive(:set_channel).with(d[:channel])
            expect(@crazyradio).to receive(:set_data_rate).with(d[:data_rate])
            expect(@crazyradio).to receive(:set_arc).with(d[:arc])
            scr = :set_cont_carrier
            expect(@crazyradio).to receive(scr).with(d[:cont_carrier])
            expect(@crazyradio).to receive(:set_address).with(d[:address])
            expect(@crazyradio).to receive(:set_power).with(d[:power])
            expect(@crazyradio).to receive(:set_ard_bytes).with(d[:ard_bytes])
            @crazyradio.apply_settings(:channel)
            @crazyradio.apply_settings(:data_rate)
            @crazyradio.apply_settings(:arc)
            @crazyradio.apply_settings(:cont_carrier)
            @crazyradio.apply_settings(:power)
            @crazyradio.apply_settings(:ard_bytes)
            @crazyradio.apply_settings(:address)
        end

        it "should apply all settings" do
            d = Crazyradio::DEFAULT_SETTINGS
            expect(@crazyradio).to receive(:set_channel).with(d[:channel])
            expect(@crazyradio).to receive(:set_data_rate).with(d[:data_rate])
            expect(@crazyradio).to receive(:set_arc).with(d[:arc])
            scr = :set_cont_carrier
            expect(@crazyradio).to receive(scr).with(d[:cont_carrier])
            expect(@crazyradio).to receive(:set_address).with(d[:address])
            expect(@crazyradio).to receive(:set_power).with(d[:power])
            expect(@crazyradio).to receive(:set_ard_bytes).with(d[:ard_bytes])
            @crazyradio.apply_settings()
        end
    end

    describe "#send_vendor_setup" do
        it "should make a control_transfer with the proper args set" do
            args = {
                :bmRequestType => LIBUSB::REQUEST_TYPE_VENDOR,
                :bRequest      => 38,
                :wValue        => 3,
                :wIndex        => 2,
                :dataOut       => ""
            }
            expect(@handle).to receive(:control_transfer).with(args)
            @crazyradio.send(:send_vendor_setup, 38, 3, 2)
        end
    end

    describe "#get_vendor_setup" do
        it "should make a control_transfer with the proper args set" do
            args = {
                :bmRequestType => LIBUSB::REQUEST_TYPE_VENDOR | 0x80,
                :bRequest      => 38,
                :wValue        => 3,
                :wIndex        => 2,
                :dataIn       => 0
            }
            expect(@handle).to receive(:control_transfer).with(args)
            resp = @crazyradio.send(:get_vendor_setup, 38, 3, 2)
            resp.should == [1,2,3]
        end
    end
end
