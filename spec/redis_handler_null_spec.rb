require "nebulous_stomp/redis_handler_null"

include NebulousStomp


describe RedisHandlerNull do

  let(:redis_hash) do
    { "connect" => {"host" => '127.0.0.1', "port" => 6379, "db" => 0} }
  end

  let(:handler) { RedisHandlerNull.new(redis_hash) }

  before(:each) do
    # by definition we should not be calling the Redis gem.
    # Arrange that if we do we get an error; because our double has no methods on it
    redisfake = double("redisfake")
    allow( Redis ).to receive(:new).and_return( redisfake )
  end


  describe "#connect" do

    it "returns self" do
      expect( handler.connect ).to eq handler
    end

  end 


  describe "#insert_fake" do

    it "sets the key/value to return" do
      handler.insert_fake('one', 'two')
      expect( handler.fake_pair ).to eq({"one" => "two"})
    end

  end


  describe "#connected?" do

    it "returns false if we didnt call run insert_fake" do
      expect( handler.connected? ).to be_falsey
    end

    it "returns true if we did call insert_fake" do
      handler.insert_fake('one', 'two')
      expect( handler.connected? ).to be_truthy
    end

  end
  
  
  describe "#set#" do

    it "supports a key, value, option parameter like the real thing" do
      expect{ handler.set('foo', 'bar', {baz: 1}) }.not_to raise_exception
    end

    it "acts like insert_fake" do
      handler.set('alice', 'tom')
      expect( handler.fake_pair ).to eq({'alice' => 'tom'})
    end

  end


  describe "#get#" do

    it "retreives the fake message regardless" do
      handler.insert_fake('grr', 'arg')
      expect( handler.get('woo') ).to eq 'arg'
    end

    it "returns nil if the fake message is not set" do
      expect( handler.get('foo') ).to be_nil
    end

  end


  describe "#del#" do

    it "resets the fake message" do
      handler.insert_fake('grr', 'arg')
      handler.del('woo')
      expect( handler.fake_pair ).to eq({})
    end

  end

end

