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


require 'crazyflie/log_conf.rb'

module Crubyflie

    # An element in the Logging Table of Contents
    # A LogTOCElement knows what the type of data that comes in a #LogBlock
    # and is able to initialize the #TOCElement from a TOC Logging packet
    class LogTOCElement < TOCElement

        # A map between crazyflie C types and ruby directives to
        # interpret them. This will help parsing the logging data
        C_RUBY_TYPE_MAP = {
            1 => {
                :ctype     => "uint8_t",
                :directive => 'C',
                :size      => 1
            },
            2 => {
                :ctype     => "uint16_t",
                :directive => 'S<',
                :size      => 2
            },
            3 => {
                :ctype     => "uint32_t",
                :directive => 'L<',
                :size      => 4
            },
            4 => {
                :ctype     => "int8_t",
                :directive => 'c',
                :size      => '1'
            },
            5 => {
                :ctype     => "int16_t",
                :directive => 's<',
                :size      => 2
            },
            6 => {
                :ctype     => "int32_t",
                :directive => 'l<',
                :size      => 4
            },
            7 => {
                :ctype     => "float",
                :directive => 'e',
                :size      => 4
            },
            # Unsupported
            # 8 => {
            #     :ctype     => "FP16",
            #     :directive => '',
            #     :size      => 2
            # }
        }

        # Initializes a Log TOC element, which means interpreting the
        # data in the packet and calling the parent class
        # @param data [String] a binary payload
        def initialize(data)
            # unpack two null padded strings
            group, name = data[2..-1].unpack('Z*Z*')
            ident = data[0].ord()
            ctype_id = data[1].ord() & 0b1111 # go from 0 to 15
            ctype = C_RUBY_TYPE_MAP[ctype_id][:ctype]
            directive = C_RUBY_TYPE_MAP[ctype_id][:directive]
            access = data[1].ord & 0b00010000 # 0x10, the 5th bit

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

    # A LogBlock represents a piece of logging information that is
    # received periodically from the Crazyflie after having set the
    # START_LOGGING command. Each LogBlock will trigger a callback when
    # a piece of data is received for it.
    #
    # Note log blocks are added/removed by the Logging class through the
    # interface provided. So you should not need to use them directly
    class LogBlock

        @@block_id_counter = 0
        attr_reader :ident, :period
        attr_writer :data_callback

        # Initialize a LogBlock
        # @param variables [Array] a set of LogConfVariables
        # @param opts [Hash] current options:
        #                    :period, in centiseconds (100 = 1s)
        def initialize(variables, opts={})
            @variables = variables || []
            @ident = @@block_id_counter
            @@block_id_counter += 1

            @period = opts.delete(:period) || 10

            @data_callback = nil
        end

        # Finds out the binary data by unpacking each of the variables
        # depending on the number of bites for the declared size
        # @param data [String] Binary data string
        def unpack_log_data(data)
            unpacked_data = {}
            position = 0
            @variables.each do |var|
                fetch_as = var.fetch_as
                map = LogTOCElement::C_RUBY_TYPE_MAP
                size = map[fetch_as][:size]
                directive = map[fetch_as][:directive]
                name = var.name
                data_to_unpack = data[position..position + size - 1]
                value = data_to_unpack.unpack(directive).first
                unpacked_data[name] = value
                position += size
            end
            @data_callback.call(unpacked_data) if @data_callback
        end
    end

    # The logging facility class
    #
    # This class is used to read packages received in the Logging port.
    # It maintains a list of log blocks, which are conveniently added,
    # or removed and for which logging is started or stopped.
    # When a packet with new information for log block comes in,
    # the block in question unpacks the data and triggers a callback.
    #
    # In Crubyflie, the Log class includes all the functionality
    # which is to be found in the Python library LogEntry class (start logging,
    # add block etc) and the Crazyflie class (callbacks for intialization), so
    # interfacing with Log should be done through this class primarily.
    #
    # Unlike the original Pyhton library, there are no callbacks registered
    # somewhere else or anything and functions being called from them. In turn,
    # the Crazyflie class will queue all the logging requests in the @in_queue
    # while a thread in the Logging class takes care of processing them
    # and doing the appropiate. This saves us from registering callbacks
    # in other places and from selecting which data we are to use here.
    class Log
        include Logging
        include CRTPConstants

        attr_reader :log_blocks, :toc
        # Store the crazyflie, find the incoming packet queue for this
        # facility and initialize a new TOC
        # @param crazyflie [Crazyflie]
        def initialize(crazyflie)
            @log_blocks = {}
            @crazyflie = crazyflie
            @in_queue = crazyflie.crtp_queues[:logging]
            @toc = TOC.new(@crazyflie.cache_folder, LogTOCElement)
            @packet_reader_thread = nil
        end

        # Refreshes the TOC. TOC class implement this step synchronously
        # so there is no need to provide callbacks or anything
        def refresh_toc
            reset_packet = packet_factory()
            reset_packet.data = [CMD_RESET_LOGGING]
            port = Crazyflie::CRTP_PORTS[:logging]
            channel = TOC_CHANNEL
            @crazyflie.send_packet(reset_packet)
            @toc.fetch_from_crazyflie(@crazyflie, port, @in_queue)
        end

        # Creates a log block with the information from a configuration
        # object.
        # @param log_conf [LogConf] Configuration for this block
        # @return [Integer] block ID if things went well,
        def create_log_block(log_conf)
            start_packet_reader_thread() if !@packet_reader_thread
            block = LogBlock.new(log_conf.variables,
                                 {:period => log_conf.period})
            block_id = block.ident
            @log_blocks[block_id] = block
            packet = packet_factory()
            packet.data = [CMD_CREATE_BLOCK, block_id]
            log_conf.variables.each do |var|
                if var.is_toc_variable?
                    packet.data << var.stored_fetch_as
                    packet.data << @toc[var.name].ident
                else
                    bin_stored_fetch_as = [var.stored_fetch_as].pack('C')
                    bin_address = [var.address].pack('L<')
                    packet.data += bin_stored_fetch_as.unpack('C*')
                    packet.data += bin_address.unpack('C*')
                end
            end
            logger.debug "Adding block #{block_id}"
            @crazyflie.send_packet(packet)
            return block_id
        end

        # Sends the START_LOGGING command for a given block.
        # It should be called after #create_toc_log_block. This call
        # will return immediately, but the provided block will be called
        # regularly as logging data is received, until #stop_logging is
        # issued for the same log
        # Crazyflie. It fails silently if the block does not exist.
        #
        # @param block_id [Integer]
        # @param data_callback [Proc] a block to be called everytime
        #                             the log data is received.
        def start_logging(block_id, &data_callback)
            block = @log_blocks[block_id]
            block.data_callback = data_callback
            return if !block
            start_packet_reader_thread() if !@packet_reader_thread
            packet = packet_factory()
            period = block.period
            packet.data = [CMD_START_LOGGING, block_id, period]
            logger.debug("Start logging on #{block_id} every #{period*10} ms")
            @crazyflie.send_packet(packet)
        end

        # Sends the STOP_LOGGING command to the crazyflie for a given block.
        # It fails silently if the block does not exist.
        # @param block_id [Integer]
        def stop_logging(block_id)
            block = @log_blocks[block_id]
            return if !block
            packet = packet_factory()
            packet.data = [CMD_STOP_LOGGING, block_id]
            logger.debug("Stop logging on #{block_id}")
            @crazyflie.send_packet(packet)
        end

        # Sends the DELETE_BLOCK command to the Crazyflie for a given block.
        # It fails silently if the block does not exist.
        # To be called after #stop_logging.
        def delete_block(block_id)
            block = @log_blocks.delete(block_id)
            return if !block
            packet = packet_factory()
            packet.data = [CMD_DELETE_BLOCK, block_id]
            @crazyflie.send_packet(packet)
        end

        # A thread that processes the queue of packets intended for this
        # facility. Recommended to start it after TOC has been refreshed.
        def start_packet_reader_thread
            stop_packet_reader_thread()
            @packet_reader_thread = Thread.new do
                Thread.current.priority = -4
                loop do
                    packet = @in_queue.pop() # block here if nothing is up
                    # @todo align these two
                    case packet.channel()
                    when LOG_SETTINGS_CHANNEL
                        handle_settings_packet(packet)
                    when LOG_DATA_CHANNEL
                        handle_logdata_packet(packet)
                    when TOC_CHANNEL
                        # We are refreshing TOC probably
                        @in_queue << packet
                        sleep 0.2
                    else
                        logger.debug("Log on #{packet.channel}. Cannot handle")
                        ## @in_queue << packet
                    end
                end
            end
        end

        # Stop the facility's packet processing
        def stop_packet_reader_thread
            @packet_reader_thread.kill() if @packet_reader_thread
            @packet_reader_thread = nil
        end

        # Finds a log block by id
        # @param block_id [Integer] the block ID
        # @return p
        def [](block_id)
            @log_blocks[block_id]
        end

        # Processes an incoming settings packet. Sort of a callback
        # @param packet [CRTPPacket] the packet on the settings channel
        def handle_settings_packet(packet)
            cmd = packet.data[0] # byte 0 of data
            payload = packet.data_repack()[1..-1] # the rest of data

            block_id = payload[0].ord()
            #See projects:crazyflie:firmware:comm_protocol#list_of_return_codes
            # @todo write down error codes in some constant
            error_st = payload[1].ord() # 0 is no error

            case cmd
            when CMD_CREATE_BLOCK
                if !@log_blocks[block_id]
                    logger.error "No log entry for #{block_id}"
                    return
                end
                if error_st != 0
                    hex_error = error_st.to_s(16)
                    mesg = "Error creating block #{block_id}: #{hex_error}"
                    logger.error(mesg)
                    return
                end
                # Block was created, let's start logging
                logger.debug "Log block #{block_id} created"
                # We do not start logging right away do we?
            when CMD_APPEND_BLOCK
                logger.debug "Received log settings with APPEND_LOG"
            when CMD_DELETE_BLOCK
                logger.debug "Received log settings with DELETE_LOG"
            when CMD_START_LOGGING
                if error_st != 0
                    hex_error = error_st.to_s(16)
                    mesg = "Error starting to log #{block_id}: #{hex_error}"
                    logger.error(mesg)
                else
                    logger.debug "Logging started for #{block_id}"
                end
            when CMD_STOP_LOGGING
                # @todo
                logger.debug "Received log settings with STOP_LOGGING"
            when CMD_RESET_LOGGING
                # @todo
                logger.debug "Received log settings with RESET_LOGGING"
            else
                mesg = "Received log settings with #{cmd}. Dont now what to do"
                logger.warn(mesg)
            end

        end
        private :handle_settings_packet

        def handle_logdata_packet(packet)
            block_id = packet.data[0]
            #logger.debug("Handling log data for block #{block_id}")
            #timestamp = packet.data[1..3] . pack and re unpack as 4 bytes
            logdata = packet.data_repack()[4..-1]
            block = @log_blocks[block_id]
            if block
                block.unpack_log_data(logdata)
            else
                logger.error "No entry for logdata for block #{block_id}"
            end
        end
        private :handle_logdata_packet

        def packet_factory
            packet = CRTPPacket.new()
            packet.modify_header(nil,
                                 CRTP_PORTS[:logging],
                                 LOG_SETTINGS_CHANNEL)
            return packet
        end
        private :packet_factory

    end
end
