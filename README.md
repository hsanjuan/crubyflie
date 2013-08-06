Crubyflie - A Ruby client and libraries for Crazyflie
=====================================================

Crubyflie is a Ruby rewrite of the [Crazyflie quadcopter](http://www.bitcraze.se/category/crazyflie/) Python [client libraries](https://bitbucket.org/bitcraze/crazyflie-pc-client)

The Crazyflie is awesome, but I did not know where to start contributing. Therefore I thought that rewriting the code in Ruby would be one way of knowing what is going on and how it works.

Additionally, I aim to provide a well tested, covered and documented code, which original libraries lack.

Any help is welcome!

Disclaimer
----------

Crubyflie is in early stage of development, very untested, unstable and probably broken. It is not my problem if you crash your Crazyflie or if it blows up (as carefully explained in GPL license).

Features
--------

 * Fly your Crazyflie using Crubyflie as client.
 * Interact programatically with the different Crazyflie facilities, such as parameters and logging.
 * Fully headless, perfect for Raspberry-Pi and console lovers.

Using
-----
TODO: Write how to use this.
TODO: Upload gem

After `gem install crubyflie`

    require 'crubyflie'
    include Crubyflie
    Crubyflie.new()
    Crubyflie.open_link('...')
    # and so on...


Contributing
------------

Contributions are awesome! :) I'd love some help here, so be invited to open issues and to send pull requests.
