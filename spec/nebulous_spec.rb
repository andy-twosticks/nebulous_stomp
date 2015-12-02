require 'spec_helper'

require 'logger'

require 'nebulous/param'


describe Nebulous do

  after(:all) { Nebulous::Param.reset }


  # Magically replaces the real Param module
  let(:param) { class_double(Nebulous::Param).as_stubbed_const }


  it 'has a version number' do
    expect(Nebulous::VERSION).not_to be nil
  end
  ##


  describe "Nebulous.set_logger" do

    it "calls Param.set_logger" do
      l = Logger.new(STDOUT)
      expect(param).to receive(:set_logger).with(l)
      Nebulous.set_logger(l)
    end

  end
  ##


  describe 'Nebulous.logger' do

    it 'returns the logger as set' do
      l = Logger.new(STDOUT)
      Nebulous.set_logger(l)

      expect( Nebulous.logger ).to eq l
    end

    it 'still works if no-one set the logger' do
      expect{ Nebulous.logger }.not_to raise_exception
      expect( Nebulous.logger ).to be_a_kind_of Logger
    end

  end
  ##
  

  describe 'Nebulous.init' do

    it 'calls Param.set' do
      h = {one: 1, two: 2}
      expect(param).to receive(:set).with(h)
      Nebulous.init(h)
    end

  end
  ##


  describe 'Nebulous.add_target' do

    it 'calls Param.add_target' do
      t1 = :foo; t2 = {bar: 'baz'}
      expect(param).to receive(:add_target).with(t1, t2)
      Nebulous.add_target(t1, t2)
    end

  end
  ##


  describe 'Nebulous.on?' do

    it 'should be true if there is anything in the stomp hash' do
      allow(param).to receive(:get).
        with(:stompConnectHash).
        and_return( foo: 'bar' )

      expect( Nebulous.on? ).to be_truthy
    end

    it 'should be false if the stomp hash is nil' do
      allow(param).to receive(:get).
        with(:stompConnectHash).
        and_return( nil, {} )

      expect( Nebulous.on? ).to be_falsy
      expect( Nebulous.on? ).to be_falsy
    end


  end
  ##


  describe 'Nebulous.redis_on?' do

    it 'is true if there is anything in the Redis connection hash' do
      allow(param).to receive(:get).
        with(:redisConnectHash).
        and_return( foo: 'bar' )

      expect( Nebulous.redis_on? ).to be_truthy
    end

    it 'is false if the Redis hash is nil or empty' do
      allow(param).to receive(:get).
        with(:redisConnectHash).
        and_return( nil, {} )

      expect( Nebulous.redis_on? ).to be_falsy
      expect( Nebulous.redis_on? ).to be_falsy
    end

  end
  ##

end


