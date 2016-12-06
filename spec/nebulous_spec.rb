require 'spec_helper'

require 'logger'

require 'nebulous_stomp/param'


describe NebulousStomp do

  before      { NebulousStomp::Param.reset }
  after(:all) { NebulousStomp::Param.reset }


  # Magically replaces the real Param module
  let(:param) { class_double(NebulousStomp::Param).as_stubbed_const }

  let(:tname) {:foo}
  let(:thash) { {sendQueue: "foo", receiveQueue: "bar"} }


  it 'has a version number' do
    expect(NebulousStomp::VERSION).not_to be nil
  end
  ##


  describe "NebulousStomp.set_logger" do

    it "calls Param.set_logger" do
      l = Logger.new(STDOUT)
      expect(param).to receive(:set_logger).with(l)
      NebulousStomp.set_logger(l)
    end

  end
  ##


  describe 'NebulousStomp.logger' do

    it 'returns the logger as set' do
      l = Logger.new(STDOUT)
      NebulousStomp.set_logger(l)

      expect( NebulousStomp.logger ).to eq l
    end

    it 'still works if no-one set the logger' do
      expect{ NebulousStomp.logger }.not_to raise_exception
      expect( NebulousStomp.logger ).to be_a_kind_of Logger
    end

  end
  ##
  

  describe 'NebulousStomp.init' do

    it 'calls Param.set' do
      h = {one: 1, two: 2}
      expect(param).to receive(:set).with(h)
      NebulousStomp.init(h)
    end

  end
  ##


  describe 'NebulousStomp.add_target' do

    it 'calls Param.add_target' do
      expect(param).to receive(:add_target) do | t|
        expect(t.name).to eq tname
        expect(t.send_queue).to eq thash[:sendQueue]
        expect(t.receive_queue).to eq thash[:receiveQueue]
      end

      NebulousStomp.add_target(tname, thash)
    end

    it 'returns the target object' do
      t = NebulousStomp.add_target(tname, thash)
      expect( t ).to be_kind_of(NebulousStomp::Target)
    end

    it "adds the name to the target hash" do
      t = NebulousStomp.add_target(tname, thash)
      expect( t.name ).to eq tname
    end

  end
  ##


  describe 'NebulousStomp.get_target' do

    before do
      NebulousStomp.add_target(tname, thash)
    end
     
    it "calls Param.get_target" do
      expect(param).to receive(:get_target).with(tname)
      NebulousStomp.get_target(tname)
    end

    it "returns the target object" do
      t = NebulousStomp.get_target(tname)
      expect( t ).to be_kind_of(NebulousStomp::Target)
      expect( t.name ).to eq tname
    end
    
  end
  ##
  

  describe 'NebulousStomp.on?' do

    it 'should be true if there is anything in the stomp hash' do
      allow(param).to receive(:get).
        with(:stompConnectHash).
        and_return( foo: 'bar' )

      expect( NebulousStomp.on? ).to be_truthy
    end

    it 'should be false if the stomp hash is nil' do
      allow(param).to receive(:get).
        with(:stompConnectHash).
        and_return( nil, {} )

      expect( NebulousStomp.on? ).to be_falsy
    end


  end
  ##


  describe 'NebulousStomp.redis_on?' do

    it 'is true if there is anything in the Redis connection hash' do
      allow(param).to receive(:get).
        with(:redisConnectHash).
        and_return( foo: 'bar' )

      expect( NebulousStomp.redis_on? ).to be_truthy
    end

    it 'is false if the Redis hash is nil or empty' do
      allow(param).to receive(:get).
        with(:redisConnectHash).
        and_return( nil, {} )

      expect( NebulousStomp.redis_on? ).to be_falsy
    end

  end
  ##

end


