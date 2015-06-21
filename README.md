Crubyflie - A Ruby client for Crazyflie
=======================================

[![Gem Version](https://badge.fury.io/rb/crubyflie.svg)](http://badge.fury.io/rb/crubyflie) [![Build Status](https://travis-ci.org/hsanjuan/crubyflie.png?branch=master)](https://travis-ci.org/hsanjuan/crubyflie) [![Coverage Status](https://coveralls.io/repos/hsanjuan/crubyflie/badge.png)](https://coveralls.io/r/hsanjuan/crubyflie)

Crubyflie is a Ruby rewrite of the [Crazyflie 1.0 quadcopter](http://www.bitcraze.se/category/crazyflie/) Python [client libraries](https://github.com/bitcraze/crazyflie-clients-python), with some customizations.

The Crazyflie is awesome, but I did not know where to start contributing. Therefore I thought that rewriting the code in Ruby would be one way of knowing what is going on and how it works. Along the way I took the time to document all the code so that others can understand it.

You may be also interested in some other unofficial Crazyflie clients:

 * C++:     https://github.com/fairlight1337/libcflie
 * Node.js: https://github.com/ceejbot/aerogel
 * Haskell: https://github.com/orclev/crazyflie-haskell

Features
--------

 * Crubyflie can be used to fly a Crazyflie device using a Joystick and the Crazyradio USB dongle
 * Crubyflie exposes an API that allows to control the copter, read logging, parameters and console easily
 * Crubyflie runs headless
 * Lightweight: If you just want to fly, Crubyflie consumes around 1/2 memory and 1/3 CPU compared to the original Python `cfheadless` utility.
 * Hovering mode (see requirements below)

Requirements
------------

Crubyflie versions `>= 0.2.0` support hovering mode and are compatible with the latest firmware of `Crazyradio` ([Version 0.53](https://github.com/bitcraze/crazyradio-firmware/releases/tag/0.53)) and `Crazyflie` ([Version 2015.1](https://github.com/bitcraze/crazyflie-firmware/releases/tag/2015.1))

Old versions should probably work, otherwise you can try with the `0.1.3` gem version.


Installation
------------

Crubyflie depends on `rubysdl`, for which you will need the SDL library and headers. Make sure you install `libsdl-dev` (Debian/Ubuntu), `libSDL-devel` (Opensuse) or whatever your distro calls it. Then:

    gem install crubyflie

That's all.

Flying the Crazyflie
--------------------

The easiest way to do it is to `gem install crubyflie` and then run the `crubyflie` command. This will connect to the first visible quadcopter using the first available joystick on your computer (you can modify this parameters with the appropiate flags):

    > crubyflie -h
    Options:
      -j, --joystick-id=<i>       Joystick ID (default: 0)
      -f, --cf-uri=<s>            Crazyflie URI (defaults to first one found in scan)
      -c, --config=<s>            Joystick configuration, defaults to default cfg in configs/ (default: /path/to/joystick_default.yaml)
      -r, --packet-retries=<i>    Number of retries when copter fails to ack a packet (-1 == forever) (default: 100)
      -d, --debug                 Enable debug messages
      -h, --help                  Show this message

There is a [template/default configuration file](https://github.com/hsanjuan/crubyflie/blob/master/configs/joystick_default.yaml) with instructions (similar to PS3 standard assignments from the official app). You should modify this file to fit it to your needs (configuration parameters are well explained). The most tricky parameter in axis is the `:max_change_rate`. Depending on your controller, you will find the input is excessively throotled or not. I recommend that you play with this value.

If you are wondering about your Joystick's axis IDs, ranges etc, you will find a `sdl-joystick-axis.rb` script under `tools` that lets you open a joystick and check what the SDL library can read from it. It might come handy.

If you need help just open an issue or contact me.

Raspberry Pi
------------

If you want to use Crubyflie in your Raspberry Pi you need to:

    sudo apt-get install ruby ruby-dev libsdl-dev
    sudo gem install crubyflie

This should provide everything you need to run the `crubyflie` command. Of course you might need to put your user in the `input` group and modify `udev` rules as explained in the [Crazyflie wiki](http://wiki.bitcraze.se/projects:crazyflie:hacks:rasberrypi).

Using the Crazyflie API
-----------------------

While both Python and Ruby APIs expose access to params, logging, console and commander facilities, Crubyflie does it in sligthly different way.

Crubyflie access to facilities is offered fully under the Crazyflie instance object, let's see it as code:

```ruby
require 'crubyflie'
include Crubyflie

# Connect
@cf = Crazyflie.new()
@cf.open_link(@radio_uri)

# Interface to the logging facility
@cf.log.create_log_block(...)
@cf.log.start_logging(...) do |log_values|
  ...
end
@cf.log.stop_logging(...)
@cf.log.delete_log(...)


# Interface to the param facility
@cf.param.get_value('param1.name') do |value|
  ...
end

@cf.param.get_value('param2.name') do |value|
  ...
end

@cf.param.set_value('param.name', 1)

# Interface to the commander facility
@cf.commander.send_setpoint(...)

# Interface to the console facility
@cf.console.read do |value|
  ...
end
```

That's pretty much all. As you see, instead of declaring callbacks, registering them etc. We let the user pass blocks, which are run when the data is available.

In Crubyflie, params are read and set synchronously, while the block passed to `start_logging()` will be called repeteadly and asynchrnously until `stop_logging()` is invoked. Console offers both synchronous `read()` and asynchronous `start_reading()` options.

**There are some examples in the `examples` folder**. Read the gem documentation to get full information of the parameters for each function call.


Contributing
------------

Contributions are awesome! :) I'd love some help here, so be invited to open issues, send pull requests or give me your opinion.
