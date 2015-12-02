require 'spec_helper'

require 'pry'

require 'nebulous/redis_handler'

include Nebulous


describe RedisHandler do

  let(:redis_hash) do
    { "connect" => {"host" => '127.0.0.1', "port" => 6379, "db" => 0} }
  end

  let(:rclient) { double('Redis Client').as_null_object }

  let(:redis) do 
    # Again, mocking all this is fragile, but I don't know of another way to
    # test the class except assuming that Redis is up, which is worse. And at
    # least we are only doing this in the test for this special handler class.
    r = double(Redis).as_null_object
    allow(r).to receive(:client).and_return(rclient)

    r
  end

  let(:handler) { RedisHandler.new(redis_hash, redis) }


  describe '#connect' do

    it '...connects...' do
      expect(rclient).to receive(:connect)
      handler.connect

      expect(handler.redis).not_to be_nil
    end

    it 'raises ConnectionError if not then connected' do
      expect(redis).to receive(:connected?).and_return(false)

      expect{ handler.connect }.to raise_exception ConnectionError
    end

  end
  ##


  describe '#quit' do

    it 'calls redis.quit when appropriate' do
      expect(redis).to receive(:quit)
      handler.connect
      handler.quit

      expect(handler.redis).to be_nil
    end

    it 'returns gracefully if we are not connected' do
      expect(redis).not_to receive(:quit)
      handler.quit
    end

  end
  ##
 

  describe '#connected?' do

    it 'returns false if we didnt call connect' do
      expect( handler.connected? ).to be_falsey
    end

    it 'passes to redis.client.connected? if we have a redis instance' do
      expect(redis).to receive(:connected?)

      handler.connect
      handler.connected?
    end

  end
  ##
  

  describe '#redis_on?' do

    it 'is true if we were passed any connection hash at all' do
      expect( RedisHandler.new(nil).redis_on? ).to be_falsy
      expect( RedisHandler.new({}).redis_on? ).to be_falsy

      expect( handler.redis_on? ).to be_truthy
    end

  end
  ##
  
  
  context 'when forwarding other methods to Redis' do

    it 'handles only set, get, and del' do
      expect(redis).to receive(:set)
      expect(redis).to receive(:get)
      expect(redis).to receive(:del)

      handler.connect
      handler.set("foo", {bar:1})
      handler.get("foo")
      handler.del("foo")

      # I "happen to know" that we are using method_missing to implement the
      # above. It's an implementation detail, but let's throw a test in for
      # that, anyway:
      expect{ handler.blewit }.to raise_exception NoMethodError
    end

    it 'raises ConnectionError if connect has not been called' do
      expect{ handler.set("foo", {bar:1}) }.
        to raise_exception Nebulous::ConnectionError

      expect{ handler.get("foo") }.to raise_exception Nebulous::ConnectionError
      expect{ handler.del("foo") }.to raise_exception Nebulous::ConnectionError
    end

    it 'raises ConnectionError if not connected' do
      allow(redis).to receive(:connected?).and_return(true,false,false,false)
      handler.connect

      expect{ handler.set("foo", {bar:1}) }.
        to raise_exception Nebulous::ConnectionError

      expect{ handler.get("foo") }.to raise_exception Nebulous::ConnectionError
      expect{ handler.del("foo") }.to raise_exception Nebulous::ConnectionError
    end


  end
  ##

end

