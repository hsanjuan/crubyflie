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

require 'timeout'

module Crubyflie
    # An element in the Parameters Table of Contents
    class ParamTOCElement < TOCElement
        # A map between crazyflie C types and ruby directives to
        # interpret them. This will help parsing the parameter data
        C_RUBY_TYPE_MAP = {
            0 => {
                :ctype     => "int8_t",
                :directive => 'c',
                :size      => 1
            },
            1 => {
                :ctype     => "int16_t",
                :directive => 's<',
                :size      => 2
            },
            2 => {
                :ctype     => "int32_t",
                :directive => 'l<',
                :size      => 4
            },
            3 => {
                :ctype     => "int64_t",
                :directive => 'q<',
                :size      => 8
            },
            5 => {
                :ctype     => "FP16",
                :directive => 'e',
                :size      => 2
            },
            6 => {
                :ctype     => "float",
                :directive => 'e',
                :size      => 4
            },
            7 => {
                :ctype     => "double",
                :directive => 'E',
                :size      => 8
            },
            8 => {
                :ctype     => "uint8_t",
                :directive => 'C',
                :size      => 1
            },
            9 => {
                :ctype     => "uint16_t",
                :directive => 'S<',
                :size      => 2
            },
            10 => {
                :ctype     => "uint32_t",
                :directive => 'L<',
                :size      => 4
            },
            11 => {
                :ctype     => "int64_t",
                :directive => 'Q<',
                :size      => '8'
            }
        }

        # Initializes a Param TOC element, which means interpreting the
        # data in the packet and calling the parent class
        # @param data [String] a binary payload
        # @todo It turns out this is the same as Log. Only the type conversion
        # changes
        def initialize(data)
            # The group and name are zero-terminated strings from the 3rd byte
            group, name = data[2..-1].unpack('Z*Z*')
            ident = data[0].ord()
            ctype_id = data[1].ord() & 0b1111  #from 0 to 15
            ctype = C_RUBY_TYPE_MAP[ctype_id][:ctype]
            directive = C_RUBY_TYPE_MAP[ctype_id][:directive]
            access = data[1].ord() & 0b00010000 # 5th bit

            super({
                      :ident => ident,
                      :group => group,
                      :name  => name,
                      :ctype => ctype,
                      :type_id => ctype_id,
                      :directive => directive,
                      :access => access
                  })
        end
    end

    # The parameter facility. Used to retrieve the table of contents,
    # set the value of a parameter and read the value of a parameter
    class Param
        include Logging
        include CRTPConstants

        attr_reader :toc
        # Initialize the parameter facility
        # @param crazyflie [Crazyflie]
        def initialize(crazyflie)
            @crazyflie = crazyflie
            @in_queue = crazyflie.crtp_queues[:param]
            @toc = TOC.new(@crazyflie.cache_folder, ParamTOCElement)
        end

        # Refreshes the TOC. It only returns when it is finished
        def refresh_toc
            channel = TOC_CHANNEL
            port = Crazyflie::CRTP_PORTS[:param]
            @toc.fetch_from_crazyflie(@crazyflie, port, @in_queue)
        end

        # Set the value of a paremeter. This call will only return after
        # a ack response has been received, or will timeout if
        # #CRTPConstants::WAIT_PACKET_TIMEOUT is reached.
        # @param name [String] parameter group.name
        # @param value [Numeric] a value. It must be packable as binary data,
        #                                the type being set in the params TOC
        # @param block [Proc] an optional block that will be called with the
        #                     response CRTPPacket received. Otherwise will
        #                     log to debug
        def set_value(name, value, &block)
            element = @toc[name]
            if element.nil?
                logger.error "Param #{name} not in TOC!"
                return
            end

            ident = element.ident
            packet = CRTPPacket.new()
            packet.modify_header(nil, CRTP_PORTS[:param],
                                 PARAM_WRITE_CHANNEL)
            packet.data = [ident]
            packet.data += [value].pack(element.directive()).unpack('C*')
            @in_queue.clear()
            @crazyflie.send_packet(packet, true) # expect answer

            response = wait_for_response()
            return if response.nil?

            if block_given?
                yield response
            else
                mesg = "Got answer to setting param '#{name}' with '#{value}'"
                logger.debug(mesg)
            end
        end

        # Request an update for a parameter and call the provided block with
        # the value of the parameter. This call will block until the response
        # has been received or the #CRTPConstants::WAIT_PACKET_TIMEOUT is
        # reached.
        # @param name [String] a name in the form group.name
        # @param block [Proc] a block to be called with the value as argument
        def get_value(name, &block)
            element = @toc[name]
            if element.nil?
                logger.error "Cannot update #{name}, not in TOC"
                return
            end
            packet = CRTPPacket.new()
            packet.modify_header(nil, CRTP_PORTS[:param],
                                 PARAM_READ_CHANNEL)
            packet.data = [element.ident]
            @in_queue.clear()
            @crazyflie.send_packet(packet, true)

            # Pop packages until mine comes up
            begin
                response = wait_for_response()
                return if response.nil?

                ident = response.data()[0]
                if ident != element.ident()
                    mesg = "Value expected for element with ID #{element.ident}"
                    mesg << " but got for element with ID #{ident}. Requeing"
                    logger.debug(mesg)
                end
            end until ident == element.ident()

            value = response.data_repack()[1..-1]
            value = value.unpack(element.directive).first
            yield(value)
        end
        alias_method :request_param_update, :get_value

        def wait_for_response
            begin
                wait = WAIT_PACKET_TIMEOUT
                response = timeout(wait, WaitTimeoutException) do
                    @in_queue.pop()
                end
                return response
            rescue WaitTimeoutException
                logger.error("Param: waited too long to get response")
                return nil
            end
        end
        private :wait_for_response
    end
end
