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

describe TOCCache do

    before :each do
        allow_any_instance_of(TOCCache).to receive(:warn)


        allow(File).to receive(:exist?).with('baa').and_return(true)
        allow(File).to receive(:directory?).with('baa').and_return(true)
        expect(FileUtils).to receive(:touch)
        expect(FileUtils).to receive(:rm)
        @cache = TOCCache.new('baa')
    end

    describe "#initialize" do
        it "shoud not create a folder where it does not have permissions" do
            allow(File).to receive(:exist?).with('baa').and_return(false)
            do_this = receive(:mkdir_p).with('baa').and_raise(Errno::EACCES)
            expect(FileUtils).to do_this
            m = "Deactivating cache. Cannot create folder"
            expect_any_instance_of(TOCCache).to receive(:warn).with(m)
            cache = TOCCache.new('baa')
        end

        it "should veryfy the cache folder is a directory" do
            allow(File).to receive(:exist?).with('baa').and_return(true)
            allow(File).to receive(:directory?).with('baa').and_return(false)
            m = "Deactivating cache. Folder is not a directory"
            expect_any_instance_of(TOCCache).to receive(:warn).with(m)
            cache = TOCCache.new('baa')
        end

        it "should test if the cache folder is writable" do
            allow(File).to receive(:exist?).with('baa').and_return(true)
            allow(File).to receive(:directory?).with('baa').and_return(true)
            allow(FileUtils).to receive(:touch).and_raise(Errno::EACCES)
            expect(FileUtils).not_to receive(:rm)
            m = "Deactivating cache. Cannot write to folder"
            expect_any_instance_of(TOCCache).to receive(:warn).with(m)
            cache = TOCCache.new('baa')
        end

        it "initialize correctly otherwise" do
            allow(File).to receive(:exist?).with('baa').and_return(true)
            allow(File).to receive(:directory?).with('baa').and_return(true)
            expect(FileUtils).not_to receive(:mkdir_p)
            expect(FileUtils).to receive(:touch)
            expect(FileUtils).to receive(:rm)
            cache = TOCCache.new('baa')
        end
    end

    describe "#fetch" do
        it "should return nil if file does not exist" do
            allow(File).to receive(:open).and_raise(Errno::ENOENT)
            expect(Marshal).not_to receive(:load)
            @cache.fetch("123").should be_nil
        end
    end

    describe "#insert" do
        it "should do nothing if an error happens" do
            allow(File).to receive(:open).and_raise(Errno::EACCES)
            expect(Marshal).not_to receive(:dump)
            @cache.insert("123",{})
        end
    end
end
