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

require 'input/joystick_input_reader'

describe Joystick do

    before :each do
        @sdl_joystick = double("Joystick")
        allow(SDL::Joystick).to receive(:update_all)
        allow(SDL).to receive(:init).with(SDL::INIT_JOYSTICK)
        allow(SDL::Joystick).to receive(:num).and_return(3)
        allow(SDL::Joystick).to receive(:open).and_return(@sdl_joystick)
        allow(SDL::Joystick).to receive(:index_name).and_return("My Joystick")
        allow(SDL::Joystick).to receive(:poll).with(false)
        expect(SDL::Joystick).not_to receive(:poll).with(true)
        @path = File.join(File.dirname(__FILE__), 'joystick_cfg.yaml')

        @joystick = Joystick.new(@path)

        @logger = @joystick.logger
        allow(@logger).to receive(:info)
        @joystick.init()
    end

    describe "#initialize" do
        it "should initialize a valid joystick supposing things go well" do
            @joystick.axis.should == {
                0 => :roll,
                1 => :pitch,
                2 => :yaw,
                3 => :thrust
            }

            @joystick.buttons.should == {
                0 => :switch_xmode,
                1 => :close_link
            }
        end
    end

    describe "#read_configuration" do
        it "should read a configuration correctly" do
            cfg = {
                :type => "Joystick",
                :axis => {0 => {:action => :yaw}},
                :buttons => {0 => {:action => :roll}}
            }
            expect(YAML).to receive(:load_file).and_return(cfg)

            axis, buttons = @joystick.read_configuration('path')
            @joystick.config[:type].should == "Joystick"
            axis.should == { 0 => :yaw }
            buttons.should == { 0 => :roll }
        end

        it "should raise exception if it cannot load the configuration" do
            expect {
                @joystick.read_configuration('baa')
            }.to raise_exception(JoystickException)
        end

        it "should raise exception if the configuration type is bad" do
            cfg = {
                :type => "BBOBOBO",
                :axis => {0 => {:action => :yaw}},
                :buttons => {0 => {:action => :roll}}
            }
            expect(YAML).to receive(:load_file).and_return(cfg)
            m = "Configuration is not of type Joystick"
            expect {
                @joystick.read_configuration('baa')
            }.to raise_exception(JoystickException, m)
        end

        it "should raise exception if the axis or buttons are missing" do
            cfg = {
                :type => "Joystick",
                :buttons => {0 => {:action => :yaw}},
            }
            expect(YAML).to receive(:load_file).and_return(cfg)
            expect {
                @joystick.read_configuration('baa')
            }.to raise_exception(JoystickException, "No axis section")
        end

        it "should raise exception if an axis has no action" do
            cfg = {
                :type => "Joystick",
                :axis => {0 => {:invert => true}},
                :buttons => {0 => {:action => :roll}}
            }
            expect(YAML).to receive(:load_file).and_return(cfg)
            expect {
                @joystick.read_configuration('baa')
            }.to raise_exception(JoystickException, "Axis 0 needs an action")
        end
    end

    describe "#init_sdl" do
        it "should raise an exception if the joystick index is invalid" do
            expect {
                js = Joystick.new(@path, 33)
                allow(js.logger).to receive(:info)
                js.init()
            }.to raise_exception(JoystickException, "No valid joystick index")
        end

        it "should open the joystick" do
            expect(SDL::Joystick).to receive(:open).with(2)
            js = Joystick.new(@path, 2)
            allow(js.logger).to receive(:info)
            js.init()
        end
    end

    describe "#read_axis" do
        it "should read the axis value with all the defaults" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 =>{
                        :action => :test,
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(-32768)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == -30
        end

        it "should put values out of range in range" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 =>{
                        :action => :test,
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(-40000)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == -30
        end

        it "should invert values if requested" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 =>{
                        :action => :test,
                        :invert => true
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(-32767)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == 30
        end

        it "should put values in the deadzone as 0" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 =>{
                        :action => :test,
                        :dead_zone => "-40:40"
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(23)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == 0
        end

        it "should normalize the thrust correctly" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 =>{
                        :action => :thrust,
                        :output_range => "0:100"
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(32767)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == 60000
        end

        it "should throotle the change rate correctly" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 => {
                        :action => :thrust,
                        :output_range => "0:100",
                        :input_range => "100:200",
                        :max_change_rate => 1,
                        :last_poll => 0.500,
                        :last_value => 34750
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)

            allow(Time).to receive(:now).and_return(1.0) # 0.5 secs after
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(140)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == 34497.5
        end

        it "should not throotle the change rate when increasing thrust" do
            config = {
                :type => "Joystick",
                :axis => {
                    8 =>{
                        :action => :thrust,
                        :output_range => "0:100",
                        :input_range => "0:100",
                        :max_change_rate => 1,
                        :last_poll => 0.500,
                        :last_value => 50
                    }
                }
            }
            expect(YAML).to receive(:load_file).and_return(config)

            allow(Time).to receive(:now).and_return(1.0) # 0.5 secs after
            expect(@sdl_joystick).to receive(:axis).with(8).and_return(100)
            @joystick.read_configuration('baa')
            value = @joystick.read_axis(8)
            value.should == 60000
        end
    end

    describe "#normalize_thrust" do
        it "should return values within the range expected by the CF" do
            v = @joystick.send(:normalize_thrust, 5000,
                               {
                                   :start => -10000.0,
                                   :end   => 10000.0,
                                   :width => 20000.0
                               },{
                                   :start => 0.0,
                                   :end   => 80.0,
                                   :width => 80.0
                               })
            v.should == 34750
            v.should be_an_instance_of Fixnum
        end

        it "should set values under the given range to the min" do
            v = @joystick.send(:normalize_thrust, 0,
                               {
                                   :start => -10000.0,
                                   :end   => 10000.0,
                                   :width => 20000.to_f
                               },{
                                   :start => 30.0,
                                   :end   => 80.0,
                                   :width => 50.0
                               })
            v.should == 24650 # 30% of 9500-60000
            v.should be_an_instance_of Fixnum
        end

        it "should set values over the given range to the max" do
            v = @joystick.send(:normalize_thrust, 32767,
                               {
                                   :start => -10000.0,
                                   :end   => +10000.0,
                                   :width => 20000.to_f
                               },{
                                   :start => 0.0,
                                   :end   => 80.0,
                                   :width => 80.0
                               })
            v.should == 49900 # 80% of 9500-60000
            v.should be_an_instance_of Fixnum
        end
    end

    describe "#read button" do
        it "should return 1 when pressed" do
            expect(@sdl_joystick).to receive(:button).and_return(true)
            v = @joystick.send(:read_button, 1)
            v.should == 1
        end
        
        it "should return -1 when not pressed" do
            expect(@sdl_joystick).to receive(:button).and_return(false)
            v = @joystick.send(:read_button, 0)
            v.should == 0
        end
    end
end
