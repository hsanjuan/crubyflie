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

describe Logging do
    it "should provide a logger" do
        include Logging
        logger.should be_an_instance_of CrubyflieLogger
    end
end

describe CrubyflieLogger do

    it "should log to debug, info, warn" do
        l = CrubyflieLogger.new(true)
        expect($stderr).to receive(:puts).with("DEBUG: a")
        expect($stdout).to receive(:puts).with("INFO: a")
        expect($stderr).to receive(:puts).with("ERROR: a")
        expect($stderr).to receive(:puts).with("WARNING: a")
        l.debug "a"
        l.info "a"
        l.warn "a"
        l.error "a"
    end
end
