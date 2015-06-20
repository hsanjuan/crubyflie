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


require 'thread'

require 'exceptions'
require 'driver/crtp_packet'
require 'crazyradio/crazyradio'



module Crubyflie
    # Small URI class since Ruby URI < 1.9.3 gives problems parsing
    # Crazyflie URIs
    class CrubyflieURI
        attr_reader :scheme, :dongle, :channel, :rate, :address
        # Initialize an URI
        # @param uri_str [String] the URI
        def initialize(uri_str)
            @uri_str = uri_str
            @scheme, @dongle, @channel, @rate, @address = split()
            if @scheme.nil? || @dongle.nil? || @channel.nil? || @rate.nil? ||
                    @scheme != 'radio'
                raise InvalidURIException.new('Bad URI')
            end
        end

        # Return URI as string
        # @return [String] a string representation of the URI
        def to_s
            @uri_str
        end

        # Quick, dirty uri split
        def split
            @uri_str.sub(':', '').sub('//','/').split('/')
        end
        private :split
    end


    # This layer takes care of connecting to the crazyradio and
    # managing the incoming and outgoing queues. This is done
    # by spawing a thread.
    # It also provides the interface to scan for available crazyflies
    # to which connect
    class RadioDriver
        # Currently used callbacks that can be passed to connect()
        CALLBACKS = [:link_quality_cb,
                     :link_error_cb]
        # Default size for the outgoing queue
        OUT_QUEUE_MAX_SIZE = 50
        # Default number of retries before disconnecting
        RETRIES_BEFORE_DISCONNECT = 10

        attr_reader :uri
        attr_reader :retries_before_disconnect, :out_queue_max_size

        # Initialize the driver. Creates new empty queues.
        def initialize()
            @uri = nil
            @in_queue = Queue.new()
            @out_queue = Queue.new()
            Thread.abort_on_exception = true
            @radio_thread = nil
            @callbacks = {}
            @crazyradio = nil
            @out_queue_max_size = nil
            @retries_before_disconnect = nil
            @shutdown_thread = false
        end

        # Connect to a Crazyflie in the specified URI
        # @param uri_s [String] a radio uri like radio://<dongle>/<ch>/<rate>
        # @param callbacks [Hash] blocks to call (see CALLBACKS contant values)
        # @param opts [Hash] options. Currently supported
        #                    :retries_before_disconnect (defaults to 20) and
        #                    :out_queue_max_size (defaults to 50)
        # @raise [CallbackMissing] when a necessary callback is not provided
        #                          (see CALLBACKS constant values)
        # @raise [InvalidURIException] when the URI is not a valid radio URI
        # @raise [OpenLink] when a link is already open
        def connect(uri_s, callbacks={}, opts={})
            # Check if apparently there is an open link

            if @crazyradio
                m = "Active link to #{@uri.to_s}. Disconnect first"
                raise OpenLink.new(m)
            end

            # Parse URI to initialize Crazyradio
            # @todo: better control input. It defaults to 0
            @uri = CrubyflieURI.new(uri_s)
            dongle_number = @uri.dongle.to_i
            channel = @uri.channel.to_i
            rate = @uri.rate
            address = @uri.address

            if address
                begin
                    # The official driver does this. Takes address as decimal
                    # number, calculate the binary and pack it as 5 byte.
                    hex_addr = address.to_i.to_s(16)
                    bin_addr = hex_addr.scan(/../).map { |x| x.hex }.pack('C*')
                    address = bin_addr.unpack('CCCCC')
                rescue
                    raise InvalidURIException.new("Address not valid: #{$!.message}")
                end
            end

            # @todo this should be taken care of in crazyradio
            case rate
            when "250K"
                rate = CrazyradioConstants::DR_250KPS
            when "1M"
                rate = CrazyradioConstants::DR_1MPS
            when "2M"
                rate = CrazyradioConstants::DR_2MPS
            else
                raise InvalidURIException.new("Bad radio rate")
            end

            # Fill in the callbacks Hash
            CALLBACKS.each do |cb|
                if passed_cb = callbacks[cb]
                    @callbacks[cb] = passed_cb
                else
                    raise CallbackMissing.new("Callback #{cb} mandatory")
                end
            end

            @retries_before_disconnect = opts[:retries_before_disconnect] ||
                RETRIES_BEFORE_DISCONNECT
            @out_queue_max_size = opts[:out_queue_max_size] ||
                OUT_QUEUE_MAX_SIZE

            # Initialize Crazyradio and run thread
            cradio_opts = {
                :channel => channel,
                :data_rate => rate,
                :address => address
            }
            @crazyradio = Crazyradio.factory(cradio_opts)
            start_radio_thread()

        end

        # Disconnects from the crazyradio
        # @param force [TrueClass, FalseClass]. Kill the thread right away, or
        #                                       wait for out_queue to empty
        def disconnect(force=nil)
            kill_radio_thread(force)
            @in_queue.clear()
            @out_queue.clear()

            return if !@crazyradio
            @crazyradio.close()
            @crazyradio = nil
        end

        # Place a packet in the outgoing queue
        # When not connected it will do nothing
        # @param packet [CRTPPacket] The packet to send
        def send_packet(packet)
            return if !@crazyradio
            if (s = @out_queue.size) >= @out_queue_max_size
                m = "Reached #{s} elements in outgoing queue"
                @callbacks[:link_error_cb].call(m)
                disconnect()
            end

            @out_queue << packet if !@shutdown_thread
        end

        # Fetch a packet from the incoming queue
        # @return [CRTPPacket,nil] a packet from the queue,
        #                           or nil when there is none
        def receive_packet(non_block=true)
            begin
                return @in_queue.pop(non_block)
            rescue ThreadError
                return nil
            end
        end

        # List available Crazyflies in the provided channels
        # @param start [Integer] channel to start
        # @param stop [Intenger] channel to stop
        # @return [Array] list of channels where a Crazyflie was found
        def scan_radio_channels(start = 0, stop = 125)
            return @crazyradio.scan_channels(start, stop)
        end
        private :scan_radio_channels

        # List available Crazyflies
        # @return [Array] List of radio URIs where a crazyflie was found
        # @raise [OpenLink] if the Crazyradio is connected already
        def scan_interface
            raise OpenLink.new("Cannot scan when link is open") if @crazyradio
            begin
                @crazyradio = Crazyradio.factory()
                results = {}
                @crazyradio[:arc] = 1
                @crazyradio[:data_rate] = Crazyradio::DR_250KPS
                results["250K"] = scan_radio_channels()
                @crazyradio[:data_rate] = Crazyradio::DR_1MPS
                results["1M"]   = scan_radio_channels()
                @crazyradio[:data_rate] = Crazyradio::DR_2MPS
                results["2M"]   = scan_radio_channels()

                uris = []
                results.each do |rate, channels|
                    channels.each do |ch|
                        uris << "radio://0/#{ch}/#{rate}"
                    end
                end
                return uris
            rescue USBDongleException
                raise
            rescue Exception
                retries ||= 0
                logger.error("Error scanning interface: #{$!}")
                retries += 1
                if retries < 2
                    logger.error("Retrying")
                    sleep 0.5
                    retry
                end
                return []
            ensure
                @crazyradio.close() if @crazyradio
                @crazyradio = nil
            end
        end


        # Get status from the crazyradio. @see Crazyradio#status
        def get_status
            return Crazyradio.status()
        end


        # Privates
        # The body of the communication thread
        # Sends packets and tries to read the ACK
        # @todo it is long and ugly
        # @todo why the heck do we care here if we need to wait? Should the
        # crazyradio do the waiting?
        def start_radio_thread
            @radio_thread = Thread.new do
                Thread.current.priority = 5
                out_data = [0xFF]
                retries = @retries_before_disconnect
                should_sleep = 0
                error = "Unknown"
                while true do
                    begin
                        ack = @crazyradio.send_packet(out_data)
                        # possible outcomes
                        # -exception - no usb dongle?
                        # -nil - bad comm
                        # -AckStatus class
                    rescue Exception
                        error = "Error talking to Crazyradio: #{$!.to_s}"
                        break
                    end

                    if ack.nil?
                        error = "Dongle communication error (ack is nil)"
                        break
                    end

                    # Set this in function of the retries
                    quality = (10 - ack.retry_count) * 10
                    @callbacks[:link_quality_cb].call(quality)

                    # Retry if we have not reached the limit
                    if !ack.ack
                        retries -= 1
                        next if retries > 0
                        error = "Too many packets lost"
                        break
                    else
                        retries = @retries_before_disconnect
                    end

                    # If there is data we queue it in incoming
                    # Otherwise we increase should_sleep
                    # If there is no data for more than 10 times
                    # we will sleep 0.01s when our outgoing queue
                    # is empty. Otherwise, we just send what we have
                    # of the 0xFF packet
                    data = ack.data
                    if data.length > 0
                        @in_queue << CRTPPacket.unpack(data)
                        should_sleep = 0
                    else
                        should_sleep += 1
                    end

                    break if @shutdown_thread && @out_queue.empty?()

                    begin
                        out_packet = @out_queue.pop(true) # non-block
                        should_sleep += 1
                    rescue ThreadError
                        out_packet = CRTPPacket.new(0xFF)
                        sleep 0.01 if should_sleep >= 10
                    end

                    out_data = out_packet.pack
                end
                if !@shutdown_thread
                    # If we reach here it means we are dying because of
                    # an error. The callback will likely call disconnect, which
                    # tries to kills us, but cannot because we are running the
                    # callback. Therefore we set @radio_thread to nil and then
                    # run the callback.
                    @radio_thread = nil
                    @callbacks[:link_error_cb].call(error)
                end
            end
        end
        private :start_radio_thread

        def kill_radio_thread(force=false)
            if @radio_thread
                if force
                    @radio_thread.kill()
                else
                    @shutdown_thread = true
                    @radio_thread.join()
                end
                @radio_thread = nil
                @shutdown_thread = false
            end
        end
        private :kill_radio_thread



        # def pause_radio_thread
        #     @radio_thread.stop if @radio_thread
        # end
        # private :pause_radio_thread


        # def resume_radio_thread
        #     @radio_thread.run if @radio_thread
        # end
        # private :resume_radio_thread


        # def restart_radio_thread
        #     kill_radio_thread()
        #     start_radio_thread()
        # end
        # private :restart_radio_thread
    end
end
