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

require 'crazyflie/toc'

describe TOCElement do
    describe "#initialize" do
        it "should assign the variables correctly" do
            te = TOCElement.new({
                                    :ident => 1,
                                    :group => 2,
                                    :name => 3,
                                    :ctype => 4,
                                    :directive => 'C*',
                                    :access => 6
                                })
            te.ident.should == 1
            te.group.should == 2
            te.name.should == 3
            te.ctype.should == 4
            te.directive.should == 'C*'
            te.access.should == 6
        end
    end
end

describe TOC do
    before :each do
        @cache = double("TOCCache")
        allow(TOCCache).to receive(:new).and_return(@cache)
        @toc = TOC.new()
        @element = TOCElement.new({
                                    :ident => 1,
                                    :group => "mygroup",
                                    :name => "myname",
                                    :ctype => 4,
                                    :rtype => 5,
                                    :access => 6
                                })
    end

    describe "#initialize" do
        it "should setup the cache" do
            expect(TOCCache).to receive(:new).with('abc')
            toc = TOC.new('abc')
        end
    end

    describe "#[]" do
        it "should find an element by name only" do
            @toc.insert(@element)
            @toc["myname",:by_name].should == @element
            @toc["mygroup.myname",:by_name].should == @element
            @toc[1,:by_name].should be_nil
        end

        it "should find an element by id only" do
            @toc.insert(@element)
            @toc["myname",:by_id].should be_nil
            @toc[1,:by_id].should == @element
        end

        it "should find an element by both name and id" do
            @toc.insert(@element)
            @toc["myname"].should == @element
            @toc[1].should == @element
        end

        it "should return nil when the element is not found" do
            @toc.insert(@element)
            @toc["baa"].should be_nil
        end
    end

    describe "#insert" do
        it "should insert correctly an element" do
            @toc[1].should be_nil
            @toc.insert(@element)
            @toc[1].should == @element
        end
    end

    describe "#import/#export" do
        it "should import and export" do
            expect(@cache).to receive(:insert).with('abc', @toc.toc)
            expect(@cache).to receive(:fetch).with('abc').and_return({:a => 3})

            @toc.insert(@element)
            @toc.export_to_cache('abc')
            @toc.import_from_cache('abc')
            @toc.toc.should == {:a => 3}
        end
    end

    describe "#fetch_from_crazyflie" do
        it "should import from cache when the TOC is in it" do
            cf = double("Crazyflie")
            queue = Queue.new
            resp = CRTPPacket.new()
            resp.modify_header(nil, 0, TOC_CHANNEL)
            resp.data = [0, 5, 0x01, 0x00, 0x00, 0x00, 0x00]
            bad_resp = CRTPPacket.new()
            bad_resp.modify_header(nil, 0, 33)

            allow(@cache).to receive(:fetch).and_return({:abc => "def"}).once

            expect(queue).to receive(:pop).and_return(bad_resp, resp).twice
            expect(queue).to receive(:<<).with(bad_resp)
            expect(cf).to receive(:send_packet).with(anything, true).once
            m = "Got a non-TOC packet. Requeueing..."
            m2 = "TOC crc #{1}, 5 items"
            m3 = "TOC found in cache"
            expect(@toc).to receive(:warn).with(m)
            expect(@toc).to receive(:puts).with(m2)
            expect(@toc).to receive(:puts).with(m3)

            @toc.fetch_from_crazyflie(cf, 0, queue)
        end

        it "should request the elements in the TOC when it is not in cache" do
            cf = double("Crazyflie")
            queue = Queue.new
            resp = CRTPPacket.new()
            resp.modify_header(nil, 0, TOC_CHANNEL)
            resp.data = [0, 5, 0x01, 0x00, 0x00, 0x00, 0x00]

            resp_elem = CRTPPacket.new()
            resp_elem.modify_header(nil, 0, TOC_CHANNEL)
            resp_elem.data = [0, 0, 0xFF, 0xFF]

            allow(@cache).to receive(:fetch).and_return(nil).once

            do_this = receive(:pop).and_return(resp,
                                               resp_elem).exactly(6).times
            expect(queue).to do_this
            expect(cf).to receive(:send_packet).with(anything,
                                                     true).exactly(6).times

            mw = "Not in cache"
            m = "TOC crc 1, 5 items"
            m0 = "Added 0 to TOC"
            m1 = "Added 1 to TOC"
            m2 = "Added 2 to TOC"
            m3 = "Added 3 to TOC"
            m4 = "Added 4 to TOC"

            expect(@toc).to receive(:warn).with(mw)
            expect(@toc).to receive(:puts).with(m)
            expect(@toc).to receive(:puts).with(m0)
            expect(@toc).to receive(:puts).with(m1)
            expect(@toc).to receive(:puts).with(m2)
            expect(@toc).to receive(:puts).with(m3)
            expect(@toc).to receive(:puts).with(m4)

            one = { :ident => 0 }
            two = { :ident => 1 }
            three = { :ident => 2 }
            four = { :ident => 3 }
            five = { :ident => 4 }
            allow(TOCElement).to receive(:new).and_return(
                                                          TOCElement.new(one),
                                                          TOCElement.new(two),
                                                          TOCElement.new(three),
                                                          TOCElement.new(four),
                                                          TOCElement.new(five))

            expect(@cache).to receive(:insert).with("1", anything)
            @toc.fetch_from_crazyflie(cf, 0, queue)
        end
    end
end
