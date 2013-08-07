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
    # Raised when the radio URI is invalid
    class InvalidURIType < Exception; end
    # Raised when an radio link is already open
    class OpenLink < Exception; end
    # Raised when a radio driver callback parameter is missing
    class CallbackMissing < Exception; end
    # Raised when no USB dongle can be found
    class NoDongleFound < Exception; end
    # Raised when a problem occurs with the USB dongle
    class USBDongleException < Exception; end
    # Raised when a problem happens in the radio driver communications thread
    class RadioThreadException < Exception; end
end
