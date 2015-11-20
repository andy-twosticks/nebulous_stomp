require 'spec_helper'
require 'nebulous/param'

include Nebulous


describe Param do

  before do
    Param.set()
  end


  describe "Param::set" do

    it "resets the param string" do
      expect( Param.get_all).to eq(Param::ParamDefaults)
    end

    it "rejects any weird parameters passed to it" do
      expect { Param.set({:notARealParameter => 1}) }.to \
        raise_exception NebulousError

    end

    it "adds legitimate parameters to the param hash" do
      Param.set( redisConnectHash: {boo: 1} )

      expect( Param.get_all[:redisConnectHash] ).to eq( {boo: 1} )
    end

  end # of Param::set
  ##


  describe "Param::add_target" do

    it "rejects unkown values in the param string for the target" do
      expect { Param.add_target(:foo, {:notAValidThing => 14}) }.to \
        raise_exception NebulousError

    end

    it "expects both a send queue and a receive queue" do
      h = {receiveQueue: '/queue/foo'}
      expect{ Param.add_target(:foo, h) }.to raise_exception(NebulousError)

      h = {sendQueue: '/queue/foo'}
      expect{ Param.add_target(:foo, h) }.to raise_exception(NebulousError)
    end

    it "adds legitimate parameters to the target hash" do
      h = {receiveQueue: '/queue/foo', sendQueue: '/queue/bar'}
      Param.add_target(:foo, h)

      expect( Param.get_all[:targets][:foo] ).to include(h)
    end


  end # of Param:add_target
  ##


  describe "Param::get" do
    before do
      @hash = { stompConnectHash: {one: 1, two: 2},
                redisConnectHash: {three: 4, five: 6},
                messageTimeout:   7,
                cacheTimeout:     888 }

      Param.set(@hash)
    end


    it "returns the given hash value" do
      expect( Param.get(:redisConnectHash) ).to eq(@hash[:redisConnectHash])
      expect( Param.get(:messageTimeout)   ).to eq(7)
    end


  end # of param::get
  ##


  describe "Param::get_target" do
    before do
      @targ = {receiveQueue: 'foo', sendQueue: 'bar'}
      Param.add_target(:one, @targ)
    end


    it "throws an exception if you ask for a target it doesn't have" do
      expect{ Param.get_target(:two) }.to raise_exception(NebulousError)
    end

    it "returns the target hash corresponding to the name" do
      expect( Param.get_target(:one) ).to include(@targ)
    end

      
  end # of get_target
  ##


  describe "Param::get_logger" do

    it "returns the logger instance" do
      l = Logger.new(STDOUT)
      Param.set_logger(l)

      expect( Param.get_logger ).to eq l
    end

  end
  ##


end


