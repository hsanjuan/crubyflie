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

require 'crazyflie/param'



describe LogTOCElement do
    describe "#initialize" do
        it "should initialize correctly" do
            data = [5, 23].pack('C*') + ['hello', 'world'].pack('Z*Z*')
            lte = ParamTOCElement.new(data)
            lte.ident.should == 5
            lte.group.should == 'hello'
            lte.name.should  == 'world'
            lte.ctype.should == 'double'
            lte.directive.should == 'E'
            lte.access.should == 0x10
        end
    end
end


describe Param do
    before :each do
        @crazyflie = double("Crazyflie")
        @queue = Queue.new
        allow(@crazyflie).to receive(:crtp_queues).and_return({:param =>
                                                                  @queue})
        allow(@crazyflie).to receive(:cache_folder).and_return(nil)

        @param = Param.new(@crazyflie)
    end

    describe "#initialize" do
        it "should initialize the Param instance" do
            param = Param.new(@crazyflie)
            @param.toc.toc.should == {}
        end
    end

    describe "#refresh_toc" do
        it "send the packet and fetch the TOC from the crazyflie" do
            port = Crazyflie::CRTP_PORTS[:param]
            channel = Param::TOC_CHANNEL
            expect(@param.toc).to receive(:fetch_from_crazyflie).with(
                                                                    @crazyflie,
                                                                    port,
                                                                    channel,
                                                                    @queue)
            @param.refresh_toc()
        end
    end

    describe "#set_value" do
        it "should not do anything if the element is not in the TOC" do
            expect(@param).to receive(:warn).with("Param abc not in TOC!")
            expect(@crazyflie).not_to receive(:send_packet)
            @param.set_value('abc', 45)
        end

        it "should set the value of a parameter and yield the response" do
            toc_elem = TOCElement.new({
                                          :ident => 3,
                                          :group => "gr",
                                          :name => "name",
                                          :ctype => "int32_t",
                                          :directive => "l<"
                                      })

            name = 'gr.name'
            expect(@param.toc).to receive(:[]).with(name).and_return(toc_elem)

            expect(@crazyflie).to receive(:send_packet) { |packet, expect|
                packet.port.should == CRTP_PORTS[:param]
                packet.channel == PARAM_WRITE_CHANNEL
                packet.data.should == [3, 1, 0, 0, 0]
                expect.should == true
            }

            res = CRTPPacket.new()
            @queue << res

            @param.set_value('gr.name', 1) do |response|
                response.should == res
            end
        end

        it "should set the value of a parameter without a block_given" do
            toc_elem = TOCElement.new({
                                          :ident => 3,
                                          :group => "gr",
                                          :name => "name",
                                          :ctype => "int32_t",
                                          :directive => "l<"
                                      })

            name = 'gr.name'
            expect(@param.toc).to receive(:[]).with(name).and_return(toc_elem)

            expect(@crazyflie).to receive(:send_packet) { |packet, expect|
                packet.port.should == CRTP_PORTS[:param]
                packet.channel == PARAM_WRITE_CHANNEL
                packet.data.should == [3, 1, 0, 0, 0]
                expect.should == true
            }

            res = CRTPPacket.new()
            @queue << res

            m = "Got answer to setting param 'gr.name' with '1'"
            expect(@param).to receive(:puts).with(m)
            @param.set_value('gr.name', 1)
        end
    end

    describe "#get_value" do
        it "should not do anything if the element is not in the TOC" do
            m = "Cannot update gr.name, not in TOC"
            expect(@param).to receive(:warn).with(m)

            @param.get_value('gr.name') {}
        end

        it "should request an element and yield the value" do
            toc_elem = TOCElement.new({
                                          :ident => 3,
                                          :group => "gr",
                                          :name => "name",
                                          :ctype => "int32_t",
                                          :directive => "l<"
                                      })

            name = 'gr.name'
            expect(@param.toc).to receive(:[]).with(name).and_return(toc_elem)

            expect(@crazyflie).to receive(:send_packet) do |packet|
                packet.port.should == CRTP_PORTS[:param]
                packet.channel.should == PARAM_READ_CHANNEL
                packet.data.should == [3]
            end

            res = CRTPPacket.new()
            res.data = [3, 5, 0, 0, 0]
            @queue << res
            @param.get_value('gr.name') do |value|
                value.should == 5
            end
        end
    end
end
