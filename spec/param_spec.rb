require 'spec_helper'
require 'nebulous_stomp/param'

include NebulousStomp


describe Param do

  before      { Param.reset }
  after(:all) { Param.reset }


  describe "Param.set" do

    it "resets the param string" do
      Param.set
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


  describe "Param.add_target" do

    let(:hash1) { {receiveQueue: '/queue/foo', sendQueue: '/queue/bar'} }

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

    it 'works even when set has not been called' do
      Param.reset
      expect{ Param.add_target(:foo, hash1) }.not_to raise_exception
    end

    it "adds legitimate parameters to the target hash" do
      Param.add_target(:foo, hash1)
      expect( Param.get_all[:targets][:foo] ).to include(hash1)
    end

  end # of Param:add_target
  ##


  describe "Param.get" do

    let(:hash1) { { stompConnectHash: {one: 1, two: 2},
                    redisConnectHash: {three: 4, five: 6},
                    messageTimeout:   7,
                    cacheTimeout:     888 } }

    it "returns the given hash value" do
      Param.set(hash1)
      expect( Param.get(:redisConnectHash) ).to eq(hash1[:redisConnectHash])
      expect( Param.get(:messageTimeout)   ).to eq(7)
    end

    it 'does not freak out if set() was never called' do
      expect{ Param.get(:foo) }.not_to raise_exception
    end

  end # of param::get
  ##


  describe "Param.get_target" do

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

    it 'does not freak out if set() was never called' do
      Param.reset
      expect{ Param.get_target(:one) }.not_to raise_exception
    end
      
  end # of get_target
  ##


  describe "Param.get_logger" do

    it "returns the logger instance" do
      l = Logger.new(STDOUT)
      Param.set_logger(l)

      expect( Param.get_logger ).to eq l
    end

    it 'does not freak out if set_logger() was never called' do
      Param.reset
      expect{ Param.get_logger }.not_to raise_exception
    end

  end
  ##


  describe "Param.set_logger" do

    it "requires an instance of Logger, or nil" do
      expect{ NebulousStomp.set_logger(:foo) }.to raise_exception NebulousError

      expect{ NebulousStomp.set_logger(nil) }.not_to raise_exception
      expect{ NebulousStomp.set_logger( Logger.new(STDOUT) ) }.not_to raise_exception
    end

  end
  ##


end


