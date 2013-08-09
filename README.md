Crubyflie - A Ruby client and libraries for Crazyflie
=====================================================

Crubyflie is a Ruby rewrite of the [Crazyflie quadcopter](http://www.bitcraze.se/category/crazyflie/) Python [client libraries](https://bitbucket.org/bitcraze/crazyflie-pc-client), with some customizations.

The Crazyflie is awesome, but I did not know where to start contributing. Therefore I thought that rewriting the code in Ruby would be one way of knowing what is going on and how it works. Along the way I took the time to document all the code so that others can understand it and create tests.

Any help is welcome!

Disclaimer
----------

Crubyflie is in early stage of development, very untested.

Features
--------

 * Crubyflie can be used to fly a Crazyflie device using a Joystick and the Crazyradio USB dongle
 * Crubyflie exposes an API that allows to control the copter, read logging and parameters, console easily
 * Crubyflie runs headless

Fyling the Crazyflie
--------------------


Using the Crazyflie API
-----------------------

While both Python and Ruby APIs expose access to params, logging, console and commander facilities, Crubyflie does it in sligthly different way.

Crubyflie access to facilities is offered fully under the Crazyflie instance object:

```ruby
require 'crubyflie'
include Crubyflie

# Connect
@cf = Crazyflie.new()
@cf.open_link(@radio_uri)

# Interface to the logging facility
@cf.log.create_log_block(...)
@cf.log.start_logging(...) do |log_values|

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

end
```

That's pretty much all. As you see, instead of declaring callbacks, registering them etc. We let the user pass blocks, which are run when the data is available. In Crubyflie, params are read and set synchronously, while the block passed to `start_logging()` will be called repeteadly and asynchrnously until `stop_logging()` is invoked. Console offers both synchronous `read()` and asynchronous `start_reading()` options.

There are some examples in the `examples` folder. Read the gem documentation to get full information of the parameters for each function call.


Contributing
------------

Contributions are awesome! :) I'd love some help here, so be invited to open issues, send pull requests or give me your opinion.
