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

    # Interface for Logging configuration objects
    # this class lists methods to be implemented
    class LogConf
        # returns the variables that are logged in this logging
        # configuration
        # @return [Array[LogConfVariable]] list of variables
        def variables ; end
    end

    # Interface for Logging variable configuration objects
    # this class lists methods to be implemented
    # Python implementation is in cfclient/utils/logconfigreader.py
    class LogConfVariable
        # @return [String] name of this variable
        def name ; end
        # @return [Integer] a byte where the upper 4 bits are the
        # type indentifier of how the variable is stored and the lower
        # 4 bits are the type the variable should be fetched as
        def stored_fetch_as ; end
        # @return [Integer] the code indentifying the type used to store the
        #                   variable
        def stored_as; end
        # @return [Integer] the code indentifying the type used to fetch the
        #                   variable
        def fetch_as ; end
        # @return [TrueClass,FalseClass] true if it is stored in the TOC
        def is_toc_variable? ; end
    end
end
