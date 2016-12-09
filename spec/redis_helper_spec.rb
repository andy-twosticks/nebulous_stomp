require 'json'

require 'nebulous_stomp/redis_helper'
require 'nebulous_stomp/redis_handler_null'

include NebulousStomp


describe RedisHelper do

  before do
    @redis_handler = RedisHandlerNull.new(@redis_hash)
  end

  let(:helper) do
    helper = RedisHelper.new
    helper.redis_handler = @redis_handler
    helper
  end

  def insert_fake( value={woof: true} )
    @redis_handler.insert_fake( "bark", value.to_json )
  end



  describe "set" do

    it "takes a key and a value" do
      expect{ helper.set(:foo, "bar") }.not_to raise_error
    end

    it "takes an optional timeout" do
      expect{ helper.set(:foo, "bar", "baz") }.to raise_error ArgumentError
      expect{ helper.set(:foo, "bar", 14)    }.not_to raise_error
    end

    it "calls RedisHandler.set to write the value" do
      expect( @redis_handler ).to receive(:set).with("foo", "bar")
      helper.set(:foo, "bar")

      expect( @redis_handler ).to receive(:set).with("foo", "bar", 14)
      helper.set(:foo, "bar", 14)
    end

  end
  ##


  describe "get" do

    it "takes a key" do
      insert_fake
      expect{ helper.get("bark") }.not_to raise_error
    end

    it "calls RedisHandler.get to retreive the value" do
      insert_fake
      expect( @redis_handler ).to receive(:get).with("bark")
      helper.get "bark"
    end

    it "returns the corresponding value" do
      insert_fake
      expect( helper.get("bark") ).to eq( {woof: true} )
      expect( helper.get(:bark)  ).to eq( {woof: true} )

      insert_fake("baaah")
      expect( helper.get("bark") ).to eq "baaah"

      insert_fake(woof: "loud")
      expect( helper.get("bark") ).to eq( {woof: "loud"} )
    end

    it "returns nil if the key does not exist in the store" do
      expect( helper.get(:bark) ).to be_nil
    end

  end
  ##


  describe "del" do

    it "takes a key" do
      insert_fake
      expect{ helper.del(:bark) }.not_to raise_error
    end

    it "calls RedisHandler.del on that key" do
      insert_fake
      expect( @redis_handler ).to receive(:del).with("bark")
      helper.del(:bark)
    end

    it "raises NebulousError if the key does not exist in the store" do
      expect{ helper.del(:bark) }.to raise_error ArgumentError
    end
    
  end
  ##
  
end


