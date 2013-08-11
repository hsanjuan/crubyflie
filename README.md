Crubyflie - A Ruby client for Crazyflie
=======================================

[![Build Status](https://travis-ci.org/hsanjuan/crubyflie.png?branch=master)](https://travis-ci.org/hsanjuan/crubyflie) [![Coverage Status](https://coveralls.io/repos/hsanjuan/crubyflie/badge.png)](https://coveralls.io/r/hsanjuan/crubyflie)

Crubyflie is a Ruby rewrite of the [Crazyflie quadcopter](http://www.bitcraze.se/category/crazyflie/) Python [client libraries](https://bitbucket.org/bitcraze/crazyflie-pc-client), with some customizations.

The Crazyflie is awesome, but I did not know where to start contributing. Therefore I thought that rewriting the code in Ruby would be one way of knowing what is going on and how it works. Along the way I took the time to document all the code so that others can understand it and create tests.

You may be also interested in some other unofficial Crazyflie clients:

 * C++:     https://github.com/fairlight1337/libcflie
 * Node.js: https://github.com/ceejbot/aerogel
 * Haskell: https://github.com/orclev/crazyflie-haskell

Disclaimer
----------

Crubyflie is in early stage of development, very untested.

Features
--------

 * Crubyflie can be used to fly a Crazyflie device using a Joystick and the Crazyradio USB dongle
 * Crubyflie exposes an API that allows to control the copter, read logging, parameters and console easily
 * Crubyflie runs headless  
 * Lightweight: If you just want to fly, Crubyflie consumes around 1/2 memory and 1/3 CPU compared to the original Python `cfheadless` utility.

Not included...
----------------
 * No fancy UI.
 * No flash utility (yet?).
 * No idea how this works in other OSs that are not Linux, but in theory it should work in all with some small fixes. I welcome you to take on this task if you are interested.
 * No support for Ruby <= 1.8.7 (maybe it works who knows... I haven't tested but since Crubyflie relies heavily on threading probably it does not work so good).

Fyling the Crazyflie
--------------------

The easiest way to do it is to run the `crubyflie` command. This will connect to the first visible quadcopter using the first available joystick on your computer (you can modify this parameters with the appropiate flags):

    > crubyflie2.0 -h
    Options:
      --joystick-id, -j <i>:   Joystick ID (default: 0)
           --cf-uri, -f <s>:   Crazyflie URI (defaults to first one found in scan)
           --config, -c <s>:   Joystick configuration, defaults to default cfg in configs/ (default:
                               /usr/lib64/ruby/gems/2.0.0/gems/crubyflie-0.0.1/lib/crubyflie/input/../../../configs/joystick_default.yaml)
                 --help, -h:   Show this message

A template/default configuration file (which works for me and my PS3-like controller :)) is provided with the gem (in the `configs/` folder). You should modify this file to fit it to your needs (configuration parameters are commented). The most tricky parameter in axis is the `:max_change_rate`. Depending on your controller, you will find the input is excessively throotled or not. I recommend that you play with this value.

If you are wondering about your Joystick's axis IDs, ranges etc, you will find a `sdl-joystick-axis.rb` script under `tools` that lets you open a joystick and check what the SDL library can read from it. It might come handy.

If you need help just open an issue or contact me.

Raspberri Pi
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
@cf.param.get_value(...) do |value|
  ...
end

@cf.param.get_value(...) do |value|
  ...
end

@cf.param.set_value(...)

# Interface to the commander facility
@cf.commander.send_setpoint(...)

# Interface to the console facility
@cf.console.read do |value|
  ...
end
```

That's pretty much all. As you see, instead of declaring callbacks, registering them etc. We let the user pass blocks, which are run when the data is available. 
In Crubyflie, params are read and set synchronously, while the block passed to `start_logging()` will be called repeteadly and asynchrnously until `stop_logging()` is invoked. Console offers both synchronous `read()` and asynchronous `start_reading()` options.

There are some examples in the `examples` folder. Read the gem documentation to get full information of the parameters for each function call.


Contributing
------------

Contributions are awesome! :) I'd love some help here, so be invited to open issues, send pull requests or give me your opinion.
