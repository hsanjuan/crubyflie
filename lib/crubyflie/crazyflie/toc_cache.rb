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


# Keeps a serialized version of a TOC in disk so there is no need to
# query the Crazyflie. The files are named with the TOC CRC.

require 'fileutils'

module Crubyflie

    # Table of contents can be saved to disk and re-read from there
    # based on the CRC that they have attached. This class
    # is used for that
    class TOCCache

        # Initializes the cache directory
        # @param folder [String] a path to the folder
        def initialize(folder=nil)
            @folder = folder
            return if !@folder
            if !File.exist?(folder)
                begin
                    FileUtils.mkdir_p(folder)
                rescue Errno::EACCES
                    warn "Deactivating cache. Cannot create folder"
                    @folder = nil
                end
            elsif !File.directory?(folder)
                @folder = nil
                warn "Deactivating cache. Folder is not a directory"
                return
            else
                begin
                    test_f = File.join(folder, 'test')
                    FileUtils.touch(test_f)
                    FileUtils.rm(test_f)
                rescue Errno::EACCES
                    @folder = nil
                    warn "Deactivating cache. Cannot write to folder"
                end
            end
        end

        # Fetches a record from the cache
        # @param crc [String] the CRC of the TOC
        # @return [TOC,nil] A TOC if found
        def fetch(crc)
            return nil if !@folder
            begin
                File.open(File.join(@folder, crc), 'r') do |f|
                    Marshal.load(f.read)
                end
            rescue Errno::ENOENT, Errno::EACCES
                nil
            end
        end

        # Saves a record to the cache
        # @param crc [String] the CRC of the TOC
        # @param toc [TOC] A TOC
        def insert(crc, toc)
            return if !@folder
            begin
                File.open(File.join(@folder, crc), 'w') do |f|
                    f.write(Marshal.dump(toc))
                end
            rescue Errno::ENOENT, Errno::EACCES
            end
        end
    end
end
