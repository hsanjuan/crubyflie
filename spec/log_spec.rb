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

require 'crazyflie/log'


describe LogTOCElement do
    describe "#initialize" do
        it "should initialize correctly" do
            data = [5, 23].pack('C*') + ['hello', 'world'].pack('Z*Z*')
            lte = LogTOCElement.new(data)
            lte.ident.should == 5
            lte.group.should == 'hello'
            lte.name.should  == 'world'
            lte.ctype.should == 'float'
            lte.directive.should == 'e'
            lte.access.should == 0x10
        end
    end
end

describe LogBlock do
    describe "#initialize" do
        it "should count blocks correctly" do
            b1 = LogBlock.new([]) # 0
            b2 = LogBlock.new([]) # 1
            b3 = LogBlock.new([]) # 2
            b3.ident.should == 2
        end
    end

    describe "#unpack_log_data" do
        it "should unpack some binary data and call the callback" do
            result = nil
            cb = Proc.new do |r|
                result = r
            end

            var1 = LogConfVariable.new("var1", true, 0, 1)
            var2 = LogConfVariable.new("var2", true, 0, 2)
            var3 = LogConfVariable.new("var3", true, 0, 3)

            variables = [var1, var2, var3]

            # 1 uint8, 1 uint16 and 1 uint32
            data = [255].pack('C') + [65535].pack('S<') + [16777215].pack('L<')

            b = LogBlock.new(variables) #3
            b.data_callback = cb
            b.unpack_log_data(data)
            result.should == {
                'var1' => 255,
                'var2' => 65535,
                'var3' => 16777215
            }
        end
    end
end

describe Log do
    before :each do
        @crazyflie = double("Crazyflie")
        @queue = Queue.new
        allow(@crazyflie).to receive(:crtp_queues).and_return({:logging =>
                                                                  @queue})
        allow(@crazyflie).to receive(:cache_folder).and_return(nil)

        @log = Log.new(@crazyflie)
        @logger = @log.logger
    end

    describe "#initialize" do
        it "should intialize the Log facility" do
            @log.toc.toc.should == {}
            @log.log_blocks.should == {}
        end
    end

    describe "#refresh_toc" do
        it "send the packet and fetch the TOC from the crazyflie" do
            port = Crazyflie::CRTP_PORTS[:logging]
            channel = TOC_CHANNEL
            expect(@crazyflie).to receive(:send_packet).once
            expect(@log.toc).to receive(:fetch_from_crazyflie).with(
                                                                    @crazyflie,
                                                                    port,
                                                                    @queue)
            @log.refresh_toc()
        end
    end

    describe "#create_log_block" do
        it "should send the create block package for toc variables" do
            log_conf = double("LogConf")

            var1 = LogConfVariable.new("var1", true, 0, 1)

            var2 = LogConfVariable.new("var2", false, 0, 2, 2)
            expect(var2).not_to receive(:name)

            var3 = LogConfVariable.new("var3", true, 0, 3)
            expect(var3).not_to receive(:address)

            variables = [var1, var2, var3]
            log_conf = LogConf.new(variables, {:period => 200})

            # It is the 4th call to logblock.new in these specs
            expect(@logger).to receive(:debug).with("Adding block 4")

            packet = CRTPPacket.new()
            packet.modify_header(nil, CRTP_PORTS[:logging],
                                 LOG_SETTINGS_CHANNEL)

            packet.data = [Log::CMD_CREATE_BLOCK] + [4] +
                [1] + [1] + [2] + [2,0,0,0] + [3] + [32]

            toc1 = TOCElement.new({:ident => 1})
            toc3 = TOCElement.new({:ident => 32})
            expect(@log.toc).to receive(:[]).with('var1').and_return(toc1)
            expect(@log.toc).to receive(:[]).with('var3').and_return(toc3)

            expect(@crazyflie).to receive(:send_packet) do |pk|
                packet.header.should == pk.header
                packet.data.should == pk.data
            end
            @log.create_log_block(log_conf).should == 4
        end
    end

    describe "#start_logging" do
        it "should send the start logging packet" do
            logblock = double("logblock")
            expect(logblock).to receive(:period).and_return(30)
            expect(logblock).to receive(:data_callback=).with(an_instance_of(Proc))
            expect(@log.log_blocks).to receive(:[]).with(5).and_return(logblock)
            expect(@logger).to receive(:debug)
            expect(@crazyflie).to receive(:send_packet) do |pk|
                pk.data.should == [CMD_START_LOGGING, 5, 30]
            end
            @log.start_logging(5) do |values|
            end
        end
    end

    describe "#stop_logging" do
        it "should send the stop logging packet" do
            block = double("block")
            expect(@log.log_blocks).to receive(:[]).with(5).and_return(block)
            expect(@logger).to receive(:debug)
            expect(@crazyflie).to receive(:send_packet) do |pk|
                pk.data.should == [CMD_STOP_LOGGING, 5]
            end
            @log.stop_logging(5)
        end
    end

    describe "#delete_block" do
        it "should delete the block" do
            block = double("block")
            expect(@crazyflie).to receive(:send_packet) do |pk|
                pk.data.should == [CMD_DELETE_BLOCK, 5]
            end
            expect(@log.log_blocks).to receive(:delete).with(5).and_return({})

            @log.delete_block(5)
        end
    end

    describe "#[]" do
        it "should return a block with the given ID" do
            expect(@log.log_blocks).to receive(:[]).with(3)
            @log[3]
        end
    end

    describe "#start_packet_reader_thread" do
        it "should start a thread and process a packet" do
            packet = CRTPPacket.new()
            packet.modify_header(nil, nil, 3)
            packet.channel.should == 3 # We dont process this one
            do_this = receive(:pop).and_return(packet).at_least(:once)
            expect(@queue).to do_this
            expect(@logger).to receive(:debug).at_least(:once)
            @log.start_packet_reader_thread
            sleep 0.1
            @log.stop_packet_reader_thread
        end
    end

    describe "#handle_settings_packet" do
        # This has not many secret
        it "should go to CMD_CREATE_BLOCK case without error" do
            packet = CRTPPacket.new()
            packet.data = [CMD_CREATE_BLOCK, 33, 0]
            expect(@log).not_to receive(:puts)
            expect(@logger).to receive(:error).with("No log entry for 33")
            @log.send(:handle_settings_packet, packet)
        end

        it "should go to CMD_CREATE_BLOCK case with error" do
            packet = CRTPPacket.new()
            packet.data = [CMD_CREATE_BLOCK, 33, 3]
            expect(@logger).to receive(:error).with("Error creating block 33: 3")
            expect(@log.log_blocks).to receive(:[]).with(33).and_return({})
            @log.send(:handle_settings_packet, packet)
        end

        it "should go to CMD_START_LOGGING case without error" do
            packet = CRTPPacket.new()
            packet.data = [CMD_START_LOGGING, 33, 0]
            expect(@logger).to receive(:debug).with("Logging started for 33")
            @log.send(:handle_settings_packet, packet)
        end

        it "should go to CMD_START_LOGGING case with error" do
            packet = CRTPPacket.new()
            packet.data = [CMD_START_LOGGING, 33, 3]
            expect(@logger).to receive(:error).with("Error starting to log 33: 3")
            @log.send(:handle_settings_packet, packet)
        end
    end

    describe "#handle_logdata_packet" do
        it "should warn if no block exist" do
            expect(@log.log_blocks).to receive(:[]).with(33).and_return(nil)
            m = "No entry for logdata for block 33"
            expect(@logger).to receive(:error).with(m)
            packet = CRTPPacket.new()
            packet.data = [33, 44, 45, 46]
            @log.send(:handle_logdata_packet, packet)
        end

        it "should call the unpack log data if the block exists" do
            block =  double("Block")
            expect(block).to receive(:unpack_log_data).with([46,47].pack('C*'))
            expect(@log.log_blocks).to receive(:[]).with(33).and_return(block)
            expect(@logger).not_to receive(:error)
            packet = CRTPPacket.new()
            packet.data = [33, 44, 45, 46, 46, 47]
            @log.send(:handle_logdata_packet, packet)
        end
    end

    describe "#packet_factory" do
        it "should return a new packet on logging port and settings channel" do
            pk = @log.send(:packet_factory)
            pk.channel.should == LOG_SETTINGS_CHANNEL
            pk.port.should == CRTP_PORTS[:logging]
        end
    end
end
