require 'spec_helper'

require 'logger'

require 'nebulous_stomp/param'


describe NebulousStomp do

  before      { NebulousStomp::Param.reset }
  after(:all) { NebulousStomp::Param.reset }


  # Magically replaces the real Param module
  let(:param) { class_double(NebulousStomp::Param).as_stubbed_const }


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
      t1 = :foo; t2 = {bar: 'baz'}
      expect(param).to receive(:add_target).with(t1, t2)
      NebulousStomp.add_target(t1, t2)
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


