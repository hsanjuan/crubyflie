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

    # Constants related to CRTP Packets
    module CRTPConstants
        # The ports for the different facilities
        CRTP_PORTS = {
            :console => 0x00,
            :param => 0x02,
            :commander => 0x03,
            :logging => 0x05,
            :debugdriver => 0x0E,
            :linkctrl => 0x0F,
            :all => 0xFF
        }

        # How many seconds until we give up waiting for a packet to
        # appear in a queue
        WAIT_PACKET_TIMEOUT = 2

        # TOC channel
        TOC_CHANNEL = 0

        # Channel to retrieve Log settings
        LOG_SETTINGS_CHANNEL = 1
        # Channel to retrieve Log data
        LOG_DATA_CHANNEL = 2

        # Channel to read parameters
        PARAM_READ_CHANNEL = 1
        # Channel to write parameters
        PARAM_WRITE_CHANNEL = 2



        # Command to request a TOC element
        CMD_TOC_ELEMENT = 0
        # Command to request TOC information
        CMD_TOC_INFO = 1
        # Create block command
        CMD_CREATE_BLOCK = 0
        # Append block command
        CMD_APPEND_BLOCK = 1
        # Delete block command
        CMD_DELETE_BLOCK = 2
        # Start logging command
        CMD_START_LOGGING = 3
        # Stop logging command
        CMD_STOP_LOGGING = 4
        # Reset logging command
        CMD_RESET_LOGGING = 5


        # These come from param.rb
        # # TOC access command
        # TOC_RESET = 0
        # TOC_GETNEXT = 1
        # TOC_GETCRC32 = 2


    end


    # A data packet. Raw packet data is sent to the USB driver
    # Some related docs:
    # http://wiki.bitcraze.se/
    # projects:crazyflie:firmware:comm_protocol#serial_port
    class CRTPPacket

        attr_reader :size, :header, :channel, :port, :data
        # Initialize a package with a header and data
        # @param header [Integer] represents an 8 bit header
        # @param payload [Array] @see #set_data
        def initialize(header=0, payload=[])
            modify_header(header)
            @data = payload || []
            @size = data.size #+ 1 # header. Bytes
        end

        # Set new data for this packet and update the size
        # @param new_data [Array] the new data
        def data=(new_data)
            @data = new_data
            @size = @data.size
        end

        # Modify the full header, or the channel or the port
        # @param header [Integer] a new full header. Prevails over the rest
        # @param port [Integer] a new port (4 bits)
        # @param channel [Integer] a new channel (2 bits)
        def modify_header(header=nil, port=nil, channel=nil)
            if header
                @header = header
                @channel = header & 0b11 # lowest 2 bits of header
                @port = (header >> 4) & 0b1111    # bits 4-7
                return
            end
            if channel
                @channel = channel & 0b11 # 2 bits
                @header = (@header & 0b11111100) | @channel
            end
            if port
                @port = (port & 0b1111)  # 4 bits
                @header = (@header & 0b00001111) | @port << 4
            end
        end

        # Creates a packet from a raw data array
        def self.unpack(data)
            return CRTPPacket.new() if !data.is_a?(Array) || data.empty?()
            header = data[0]
            data = data[1..-1]
            CRTPPacket.new(header, data)
        end

        # Concat the header and the data and return it
        # @return [Array] header concatenated with data
        def pack
            [@header].concat(@data)
        end

        # Pack the data of the packet into unsigned chars when needed
        # @return [String] binary data
        def data_repack
            return @data.pack('C*')
        end
    end
end
