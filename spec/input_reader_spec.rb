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

describe InputReader do

    before :each do
        @sdl_joystick = double("Joystick")
        allow(SDL::Joystick).to receive(:update_all)
        allow(SDL).to receive(:init).with(SDL::INIT_JOYSTICK)
        allow(SDL::Joystick).to receive(:num).and_return(3)
        allow(SDL::Joystick).to receive(:open).and_return(@sdl_joystick)
        allow(SDL::Joystick).to receive(:index_name).and_return("My Joystick")
        allow(SDL::Joystick).to receive(:poll).with(false)
        expect(SDL::Joystick).not_to receive(:poll).with(true)
        path = File.join(File.dirname(__FILE__), 'joystick_cfg.yaml')
        @joystick = Joystick.new(path)

        @logger = @joystick.logger
        allow(@logger).to receive(:info)
        @joystick.init()

        @cf = double("Crazyflie")
    end

    describe "#read_input" do
        it "should read axis and buttons" do
            do_this = receive(:axis).and_return(0,32768,0,-32767)
            do_this = do_this.exactly(4).times
            expect(@sdl_joystick).to do_this

            expect(@sdl_joystick).to receive(:button) { |arg|
                false
            }.twice

            @joystick.read_input()
            @joystick.axis_readings.should == {
                :roll => 0,
                :pitch => -30,
                :yaw => 0,
                :thrust => 49900
            }

            @joystick.button_readings.should == {
                :switch_xmode => -1,
                :close_link => -1
            }
        end
    end


    describe "#apply_input" do
        it "should apply the read input to an active crazyflie" do
            do_this = receive(:axis).and_return(0,32768,0,-32767)
            do_this = do_this.exactly(4).times
            expect(@sdl_joystick).to do_this

            expect(@sdl_joystick).to receive(:button) { |arg|
                false
            }.twice

            expect(@cf).to receive(:active?).and_return(true).twice
            cmder = double("Commander")
            expect(@cf).to receive(:commander).and_return(cmder)
            expect(cmder).to receive(:send_setpoint).with(0, -30, 0,
                                                          49900, false)
            @joystick.read_input()
            @joystick.apply_input(@cf)
        end

        it "should not send commands to a non active crazyflie" do
            do_this = receive(:axis).and_return(0,32768,0,-32767)
            do_this = do_this.exactly(4).times
            expect(@sdl_joystick).to do_this

            expect(@sdl_joystick).to receive(:button) { |arg|
                false
            }.twice

            expect(@cf).to receive(:active?).and_return(false)
            expect(@cf).not_to receive(:commander)
            @joystick.read_input()
            @joystick.apply_input(@cf)
        end

        it "should close the link to the crazyflie" do
            do_this = receive(:axis).and_return(0,32768,0,-32767)
            do_this = do_this.exactly(4).times
            expect(@sdl_joystick).to do_this

            expect(@sdl_joystick).to receive(:button) { |arg|
                arg == 0 ? false : true
            }.twice

            expect(@cf).to receive(:active?).and_return(true, false).twice
            expect(@cf).not_to receive(:commander)
            expect(@cf).to receive(:close_link)
            @joystick.read_input()
            @joystick.apply_input(@cf)
        end

        it "should enable xmode" do
            do_this = receive(:axis).and_return(0,32768,0,-32767)
            do_this = do_this.exactly(4).times
            expect(@sdl_joystick).to do_this

            expect(@sdl_joystick).to receive(:button) { |arg|
                arg == 1 ? false : true
            }.twice

            expect(@cf).to receive(:active?).and_return(true).twice
            cmder = double("Commander")
            expect(@cf).to receive(:commander).and_return(cmder)
            expect(cmder).to receive(:send_setpoint).with(0, -30, 0,
                                                          49900, true)
            @joystick.read_input()
            @joystick.apply_input(@cf)
            @joystick.xmode.should == true
        end
    end

end
