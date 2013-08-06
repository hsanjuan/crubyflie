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
    # The Console facility is used to read characters that have been
    # printer using printf in the crazyflie firmware
    class Console

        # Initialize the console
        # @param crazyflie [Crazyflie]
        def initialize(crazyflie)
            @crazyflie = crazyflie
            @in_queue = crazyflie.crtp_queues[:console]
            @read_thread = nil
        end

        # Reads all the characters from the Crazyflie that are queued, until
        # the queue is empty, and then return. For each packet received,
        # the given block is called with the payload.
        # @param block [Proc] a block to call with the read information
        def read(&block)
            while @in_queue.size > 0 do
                packet = @in_queue.pop() # block
                yield(packet.data_repack) if block_given?
            end
        end


        # Reads all the characters from the Crazyflie constantly
        # and yields on the the given block is called with the payload.
        # Use stop_read() to stop.
        # @param block [Proc] a block to call with the read information
        def start_reading(&block)
            stop_reading()
            @read_thread = Thread.new do
                loop do
                    read(&block)
                    sleep 0.3 # no hurries?
                end
            end
        end

        # Stops reading characters from the Crazyflie
        def stop_reading
            @read_thread.kill() if @read_thread
            @read_thread = nil
        end
    end
end
