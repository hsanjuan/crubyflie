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

require 'libusb'

require 'exceptions'
require 'crazyradio/radio_ack'

module Crubyflie

    # This module defines some Crazyradio-related constants
    module CrazyradioConstants
        # USB dongle vendor ID
        CRAZYRADIO_VENDOR_ID = 0x1915
        # USB dongle product ID
        CRAZYRADIO_PRODUCT_ID = 0x7777

        # Set radio channel instruction code
        SET_RADIO_CHANNEL = 0x01
        # Set address instruction code
        SET_RADIO_ADDRESS = 0x02
        # Set data rate instruction code. For values see below
        SET_DATA_RATE = 0x03
        # Set radio power instruction code. For valid values see below
        SET_RADIO_POWER = 0x04
        # Set ARD (Auto Retry Delay) instruction code
        SET_RADIO_ARD = 0x05
        # Set ARC (Auto Retry Count) instruction code
        SET_RADIO_ARC = 0x06
        # Set ack instruction code
        ACK_ENABLE = 0x10
        # Set control carrier instruction code
        SET_CONT_CARRIER = 0x20
        # Scan N channels instruction code
        SCANN_CHANNELS = 0x21
        # Launch bootloader  instruction code
        LAUNCH_BOOTLOADER = 0xFF

        # Default channel to talk to a Crazyflie
        DEFAULT_CHANNEL = 2

        # 250 Kb/s datarate
        DR_250KPS = 0
        # 1 Mb/s datarate
        DR_1MPS = 1
        # 2 Mb/s datarate
        DR_2MPS = 2

        # 18db power attenuation
        P_M18DBM = 0
        # 12db power attenuation
        P_M12DBM = 1
        # 6db power attenuation
        P_M6DBM = 2
        # 0db power attenuation
        P_0DBM = 3
    end

    # Driver for the USB crazyradio dongle
    class Crazyradio
        include CrazyradioConstants
        # Default settings for Crazyradio
        DEFAULT_SETTINGS = {
            :data_rate      => DR_2MPS,
            :channel        => 2,
            :cont_carrier   => false,
            :address        => [0xE7] * 5, #5 times 0xE7
            :power          => P_0DBM,
            :arc            => 3,
            :ard_bytes      => 32 # 32
        }

        attr_reader :device, :handle, :dev_handle
        # Initialize a crazyradio
        # @param device [LIBUSB::Device] A crazyradio USB device
        # @param settings [Hash] Crazyradio settings. @see #DEFAULT_SETTINGS
        # @raise [USBDongleException] when something goes wrong
        def initialize(device=nil, settings={})
            if device.nil? || !device.is_a?(LIBUSB::Device)
                raise USBDongleException.new("Wrong USB device")
            end

            @device = device
            @handle = @device.open()
            # USB configuration 0 means unconfigured state
            @handle.configuration = 1 # hardcoded
            @handle.claim_interface(0) # hardcoded
            @settings = DEFAULT_SETTINGS
            @settings.update(settings)
            apply_settings()
        end

        # Return some information as string
        # @return [String] Dongle information
        def self.status
            cr = Crazyradio.factory()
            serial = cr.device.serial_number
            manufacturer = cr.device.manufacturer
            cr.close()
            return "Found #{serial} USB dongle from #{manufacturer}"
        end

        # Release interface, reset device and close the handle
        def close
            @handle.release_interface(0) if @handle
            @handle.reset_device() if @handle
            @handle.close() if @handle
            @device = nil
        end

        # Determines if the dongle has hardware scanning.
        # @return [nil] defaults to nil to mitigate a dongle bug
        def has_fw_scan
            # it seems there is a bug on fw scan
            nil
        end

        # Scans channels for crazyflies
        def scan_channels(start, stop, packet=[0xFF])
            if has_fw_scan()
                send_vendor_setup(SCANN_CHANNELS, start, stop, packet)
                return get_vendor_setup(SCANN_CHANNELS, 0, 0, 64)
            end

            result = []
            (start..stop).each do |ch|
                self[:channel] = ch
                status = send_packet(packet)
                result << ch if status && status.ack
            end
            return result
        end

        # Creates a Crazyradio object with the first USB dongle found
        # @return [Crazyradio] a Crazyradio
        # @raise [USBDongleException] when no USB dongle is found
        def self.factory
            devs = Crazyradio.find_devices()
            raise USBDongleException.new("No dongles found") if devs.empty?()
            return Crazyradio.new(devs.first)
        end

        # List crazyradio dongles
        def self.find_devices
            usb = LIBUSB::Context.new
            usb.devices(:idVendor  => CRAZYRADIO_VENDOR_ID,
                        :idProduct => CRAZYRADIO_PRODUCT_ID)
        end

        # Send a data packet and reads the response into an Ack
        # @param [Array] data to be sent
        def send_packet(data)
            out_args = {
                :endpoint => 1,
                :dataOut => data.pack('C*')
            }
            @handle.bulk_transfer(out_args)
            in_args = {
                :endpoint => 0x81,
                :dataIn => 64,
            }
            response = @handle.bulk_transfer(in_args)

            return nil unless response
            return RadioAck.from_raw(response, @settings[:arc])
        end

        # Set a crazyradio setting
        # @param setting [Symbol] a valid Crazyradio setting name
        # @param value [Object] the setting value
        def []=(setting, value)
            @settings[setting] = value
            apply_settings(setting)
        end

        # Get a crazyradio setting
        # @param setting [Symbol] a valid Crazyradio setting name
        # @return [Integer] the value
        def [](setting)
            return @settings[setting]
        end

        # Applies the indicated setting or all settings if not specified
        # @param setting [Symbol] a valid crazyradio setting name
        def apply_settings(setting=nil)
            to_apply = setting.nil? ? @settings.keys() : [setting]
            to_apply.each do |setting|
                value = @settings[setting]
                next if value.nil?

                case setting
                when :data_rate
                    set_data_rate(value)
                when :channel
                    set_channel(value)
                when :arc
                    set_arc(value)
                when :cont_carrier
                    set_cont_carrier(value)
                when :address
                    set_address(value)
                when :power
                    set_power(value)
                when :ard_bytes
                    set_ard_bytes(value)
                else
                    @settings.delete(setting)
                end
            end
        end

        def send_vendor_setup(request, value, index=0, dataOut=[])
            args = {
                :bmRequestType        => LIBUSB::REQUEST_TYPE_VENDOR,
                :bRequest             => request,
                :wValue               => value,
                :wIndex               => index,
                :dataOut              => dataOut.pack('C*')
            }
            @handle.control_transfer(args)
        end
        private :send_vendor_setup

        def get_vendor_setup(request, value, index, dataIn=0)
            args = {
                # Why this mask?
                :bmRequestType        => LIBUSB::REQUEST_TYPE_VENDOR | 0x80,
                :bRequest             => request,
                :wValue               => value,
                :wIndex               => index,
                :dataIn               => dataIn
            }
            return @handle.control_transfer(args).unpack('C*')
        end
        private :get_vendor_setup

        def set_channel(channel)
            send_vendor_setup(SET_RADIO_CHANNEL, channel)
        end
        private :set_channel

        def set_address(addr)
            if addr.size != 5
                raise USBDongleException.new("Address needs 5 bytes")
            end
            send_vendor_setup(SET_RADIO_ADDRESS, 0, 0, addr)
        end
        private :set_address

        def set_data_rate(datarate)
            send_vendor_setup(SET_DATA_RATE, datarate)
        end
        private :set_data_rate

        def set_power(power)
            send_vendor_setup(SET_RADIO_POWER, power)
        end
        private :set_power

        def set_arc(arc)
            send_vendor_setup(SET_RADIO_ARC, arc)
        end
        private :set_arc

        def set_ard_bytes(nbytes)
            # masking this way converts 32 to 0xA0 for example
            send_vendor_setup(SET_RADIO_ARD, 0x80 | nbytes)
        end
        private :set_ard_bytes

        def set_cont_carrier(active)
            send_vendor_setup(SET_CONT_CARRIER, active ? 1 : 0)
        end
        private :set_cont_carrier
    end
end
