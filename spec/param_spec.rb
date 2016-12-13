require 'nebulous_stomp/param'

include NebulousStomp


describe Param do

  before      { Param.send :reset }
  after(:all) { Param.send :reset }

  let(:target1) { Target.new(name: 'foo', receiveQueue: '/queue/foo', sendQueue: '/queue/bar') }


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

    it "rejects a target that's not a Target" do
      expect { Param.add_target(:notAValidThing => 14) }.to raise_exception NebulousError
    end

    it 'works even when set has not been called' do
      Param.send :reset
      expect{ Param.add_target(target1) }.not_to raise_exception
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
      Param.add_target(target1)
    end

    it "returns nil if you ask for a target it doesn't have" do
      expect( Param.get_target(:two) ).to be_nil
    end

    it "returns the Target corresponding to the name" do
      expect( Param.get_target(:foo) ).to eq target1
    end

    it 'does not freak out if set() was never called' do
      Param.send :reset
      expect{ Param.get_target(:foo) }.not_to raise_exception
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
      Param.send :reset
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


