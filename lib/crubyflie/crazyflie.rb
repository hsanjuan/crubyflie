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

require 'thread'

require 'driver/radio_driver'
require 'crazyflie/toc'
require 'crazyflie/console'
require 'crazyflie/commander'
require 'crazyflie/log'
require 'crazyflie/param'

module Crubyflie

    # This is the main entry point for interacting with a Crazyflie
    # It allows to connect to the Crazyflie on the specified radio URL
    # and make use of the different facilities: log, param, commander and
    # console. Facilities are instantiated and packages delivered to their
    # queues from here. For example, you can use
    # the @crazyflie.commander.set_sendpoint() to send a new setpoint
    # to a Crazyflie
    class Crazyflie
        include Logging
        include CRTPConstants

        # Groups of callbacks available
        CALLBACKS = [
                     :received_packet,
                     :disconnected,
                     :connection_failed,
                     :connection_initiated,
                     :connection_setup_finished,
                     :link
                    ]

        attr_accessor :callbacks
        attr_reader :cache_folder, :commander, :console, :param, :log
        attr_reader :crtp_queues, :link
        # Initialize a Crazyflie by registering default received-packet
        # callbacks and intializing Queues for every facility.
        # Packets will be queued for each facility depending on their port
        # @param cache_folder [String] folder path to store logging TOC cache
        def initialize(cache_folder=nil)
            @cache_folder = cache_folder
            # Callbacks will fire in some specific situations
            # Specially when receiving packages
            @callbacks = {}
            CALLBACKS.each do |cb|
                @callbacks[cb] = {}
            end
            register_default_callbacks()

            @crtp_queues = {}
            CRTP_PORTS.keys().each do |k|
                @crtp_queues[k] = Queue.new
            end

            # Thread that regularly checks for packages
            @receive_packet_thread = nil
            @retry_packets_thread = nil

            # A hash with keys "port_<portnumber>"
            @retry_packets = {}

            @commander = Commander.new(self)
            @console   = Console.new(self)
            @param     = Param.new(self)
            @log       = Log.new(self)

            @link = nil
        end


        # Connect to a Crazyflie using the radio driver
        # @param uri [String] radio uri to connect to
        def open_link(uri)
            call_cb(:connection_initiated, uri)
            begin
                @link = RadioDriver.new()
                link_cbs = {
                    :link_quality_cb => @callbacks[:link][:quality],
                    :link_error_cb  => @callbacks[:link][:error]
                }

                @link.connect(uri, link_cbs)
                @callbacks[:received_packet][:connected] = Proc.new do |packet|
                    logger.info "Connected!"
                    @callbacks[:received_packet].delete(:connected)
                end
                receive_packet_thread()
                sleep 0.5 # Allow setup and failures
                setup_connection() if @link
            rescue Exception
                # logger.warn $!.backtrace.join("\n")
                call_cb(:connection_failed, $!.message)
                close_link()
            end
        end

        # Close the link and clean up
        # Attemps to disconnect from the crazyflie.
        def close_link
            @commander.send_setpoint(0,0,0,0) if @link
            sleep 0.05
            uri = @link ? @link.uri.to_s : "nowhere"
            @link.disconnect(force=true) if @link
            @link = nil
            @receive_packet_thread.kill() if @receive_packet_thread
            @receive_packet_thread = nil
            @retry_packets_thread.kill() if @retry_packets_thread
            @log.stop_packet_reader_thread()
            @retry_packets.clear()
            @crtp_queues.each do |k,q|
                q.clear()
            end
            call_cb(:disconnected, uri)
        end

        # Checks if there is an open link
        # @return [TrueClass, FalseClass] true if there is an open link
        def active?
            return !@link.nil?
        end

        # Calls #RadioDriver::scan_interface()
        # @return [Array] List of radio URIs where a crazyflie was found
        def scan_interface
            if @link
                logger.error "Cannot scan when link is open. Disconnect first"
                return []
            end
            begin
                RadioDriver.new().scan_interface()
            rescue Exception
                logger.error("Cannot scan interfaces: #{$!}")
                return []
            end
        end

        # Send a packet
        # @param packet [CRTPPacket] packet to send
        # @param expect_answer [TrueClass, FalseClass] if set to true, a timer
        #                                              will be set up to
        #                                              resend the package if
        #                                              no response has been
        #                                              received in 0.1secs
        def send_packet(packet, expect_answer=false)
            return if @link.nil?
            @link.send_packet(packet)
            setup_retry(packet) if expect_answer
        end


        def receive_packet
            packet = @link.receive_packet(false) # block here
            return if packet.nil?
            call_cb(:received_packet, packet)
            port = packet.port
            facility = CRTP_PORTS.invert[port]
            queue = @crtp_queues[facility]
            if queue then queue << packet
            else logger.warn "No queue for packet on port #{port}" end
        end
        private :receive_packet

        def setup_connection
            # Logging will send other packets such RESET_LOGGING
            # We make sure to handle them by running the thread
            # while we refresh the Log TOC
            #logger.debug("Setup connection: Log TOC refresh")
            @log.start_packet_reader_thread()
            @log.refresh_toc()
            @log.stop_packet_reader_thread()
            #logger.debug("Setup connection: Param TOC refresh")
            @param.refresh_toc()
            call_cb(:connection_setup_finished, @link.uri.to_s)
        end
        private :setup_connection

        def receive_packet_thread
            @receive_packet_thread = Thread.new do
                Thread.current.priority = -2
                loop do
                    if @link.nil? then sleep 1
                    else receive_packet(); Thread.pass() end
                end
            end

            # This threads resends packets for which no answer has been
            # received.
            @retry_packets_thread = Thread.new do
                Thread.current.priority = -5

                loop do
                    @retry_packets.each do |k,v|
                        now = Time.now.to_f
                        ts = v[:timestamp]
                        if now - ts >= 0.2
                            pk = v[:packet]
                            logger.debug("Replay on #{pk.port}:#{pk.channel}")
                            send_packet(v[:packet], true)
                        end
                    end
                    sleep 0.2
                end
            end
        end
        private :receive_packet_thread

        def call_cb(cb, *args)
            @callbacks[cb].each do |name, proc|
                proc.call(*args)
            end
        end
        private :call_cb

        # Register some callbacks which are default
        def register_default_callbacks
            @callbacks[:received_packet][:delete_timer] = Proc.new do |pk|
                sym = "port_#{pk.port}".to_sym
                @retry_packets.delete(sym)
                #logger.debug("Packet: #{pk.port}: #{pk.channel}")
            end

            @callbacks[:disconnected][:log] = Proc.new do |uri|
                logger.info "Disconnected from #{uri}"
            end

            @callbacks[:connection_failed][:log] = Proc.new do |m|
                logger.error "Connection failed: #{m}"
            end

            @callbacks[:connection_initiated][:log] = Proc.new  do |uri|
                logger.info "Connection initiated to #{uri}"
            end

            @callbacks[:connection_setup_finished][:log] = Proc.new do |uri|
                logger.debug "TOCs extracted from #{uri}"
                logger.info "Connection ready!"
            end

            # The message is an integer from 0 - 100
            @callbacks[:link][:quality] = Proc.new  do |m|
                #logger.debug "Link quality #{m}"
            end

            @callbacks[:link][:error] = Proc.new  do |m|
                logger.error "Link error: #{m}"
                close_link()
            end

        end
        private :register_default_callbacks

        # A retry will fire for this request
        def setup_retry(packet)
            retry_sym = "port_#{packet.port}".to_sym
            @retry_packets[retry_sym] = {
                :packet => packet,
                :timestamp => Time.now.to_f
            }

        end
        private :setup_retry

    end
end
