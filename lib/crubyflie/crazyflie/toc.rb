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

require 'crazyflie/toc_cache'

module Crubyflie

    # Base class for a TocElement. To be extended by specific classes
    class TOCElement
        # Initializes a TOC element
        # @param element_h [Hash] indicates :ident, :group, :name, :ctype,
        #                         :rtype, :access
        attr_reader :ident, :group, :name, :ctype, :directive, :access
        def initialize(element_h)
            @ident = element_h.delete(:ident) || 0
            @group  = element_h.delete(:group) || ""
            @name  = element_h.delete(:name) || ""
            @ctype = element_h.delete(:ctype) || ""
            @directive = element_h.delete(:directive) || ""
            @access = element_h.delete(:access) || 0
        end
    end

    # A Table Of Contents
    # It is a hash that stores a group index.
    # Each group is a Hash indexed by element ID that stores TOC element
    class TOC
        include CRTPConstants
        attr_reader :toc
        # Initializes the hash
        # @param cache_folder [String] where is the cache for this toc stored
        # @param element_class [Class] the class type we should instantiate
        #                              TOC elements to, when fetching them from
        #                              the crazyflie
        def initialize(cache_folder=nil, element_class=TOCElement)
            @toc = {}
            @cache = TOCCache.new(cache_folder)
            @element_class = element_class
        end

        # Get a TOC element
        # @param name_or_id [String,Symbol] name or ident of the element
        # @param mode [Symbol] get it :by_name, :by_id, :both
        # @return [TocElement, nil] the element or nil if not found
        def [](name_or_id, mode=:both)
            by_name_element = nil
            by_id_element   = nil
            # Find by name
            if [:both, :by_name].include?(mode)
                group = name = nil
                if name_or_id.is_a?(String)
                    group, name = name_or_id.split(".", 2)
                end

                if name.nil?
                    name = group
                    group = nil
                end

                if group
                    gr = @toc[group]
                    by_name_element = gr[name] if gr
                else
                    @toc.each do |group_name, group|
                        candidate = group[name]
                        by_name_element = candidate if candidate
                        break if candidate
                    end
                end
            end

            if [:both, :by_id].include?(mode)
                @toc.each do |group_name, group|
                    group.each do |name, element|
                        by_id_element = element if element.ident == name_or_id
                        break if by_id_element
                    end
                end
            end

            return by_name_element || by_id_element
        end

        # Insert a TOC element in the TOC
        # @param element [TocElement] the name of the element group
        def insert(element)
            group = element.group
            name = element.name
            @toc[group] = {} if @toc[group].nil?
            @toc[group][name] = element
        end
        alias_method :<<, :insert

        # Saves this TOC into cache
        def export_to_cache(crc)
            @cache.insert(crc, @toc)
        end

        # Retrieves this TOC from the cache
        def import_from_cache(crc)
            @toc = @cache.fetch(crc)
        end

        # Fetches a TOC from crazyflie in a synchronous way
        # Instead of a TOCFetcher (as in the python library), we just found
        # easier to take advantage of the facility queues and read them
        # (and block when there is nothing to read) to initialize the TOC.
        # Doing it this way not only saves to have to register and chain
        # callbacks unrelated places (as Crazyflie class), but also to
        # reorder incoming TOCElement packages if they come unordered (we
        # just requeue them). This might happen if a package needs to be resent
        # and the answer for the next one comes earlier.
        #
        # This function should be preferably called before starting any
        # other activities (send/receive threads) in the relevant facilities.
        # @param crazyflie [Crazyflie] used to send packages
        # @param port [Integer] the port to send the packages
        # @param in_queue [Integer] a queue on which the responses to the
        #                           sent packages are queued
        def fetch_from_crazyflie(crazyflie, port, in_queue)
            # http://wiki.bitcraze.se/projects:crazyflie:firmware:comm_protocol
            # #table_of_content_access
            packet = CRTPPacket.new(0, [CMD_TOC_INFO])
            packet.modify_header(nil, port, TOC_CHANNEL)
            in_queue.clear()

            crazyflie.send_packet(packet, true)
            response = in_queue.pop() # we block here if none :)
            while response.channel != TOC_CHANNEL do
                in_queue << response
                warn "Got a non-TOC packet. Requeueing..."
                sleep 0.1
                response = in_queue.pop()
            end
            data = response.data
            # command = data[0]
            # Repack the payload
            payload = response.data_repack[1..-1] # get rid of byte 0
            # The crc comes in an unsigned int (L) in little endian (<)
            total_toc_items, crc = payload[0..5].unpack('CL<')
            hex_crc = crc.to_s(16)

            puts "TOC crc #{hex_crc}, #{total_toc_items} items"
            import_from_cache(hex_crc)

            if !@toc.nil? # in cache so we can stop here
                puts "TOC found in cache"
                return
            end

            warn "Not in cache"
            @toc = {}
            # We proceed to request all the TOC elements
            requested_item = 0
            while requested_item < total_toc_items do
                request_toc_element(crazyflie, requested_item, port)
                response = in_queue.pop() # block here
                if response.channel != TOC_CHANNEL
                    # Requeue
                    in_queue << response
                    warn "Got a non-TOC packet. Requeueing..."
                    sleep 0.1 # Lets give a chance to other threads
                    next
                end
                payload = response.data_repack()[1..-1] # leave byte 0 out
                toc_elem = @element_class.new(payload)
                if (a = requested_item) != toc_elem.ident()
                    warn "#{port}: Expected #{a}, but got #{toc_elem.ident}"
                    warn "Requeing"
                    # this way we are ordering items
                    in_queue << response
                    next
                end

                insert(toc_elem)
                puts "Added #{toc_elem.ident} to TOC"
                requested_item += 1
            end
            export_to_cache(hex_crc)
        end


        def request_toc_element(crazyflie, index, port)
            packet = CRTPPacket.new(0, [CMD_TOC_ELEMENT, index])
            packet.modify_header(nil, port, TOC_CHANNEL)
            crazyflie.send_packet(packet, true)
        end
        private :request_toc_element

    end
end
