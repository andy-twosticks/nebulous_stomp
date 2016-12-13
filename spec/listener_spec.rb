require 'nebulous_stomp/listener'
require 'nebulous_stomp/stomp_handler_null'

include NebulousStomp


describe Listener do

  let(:target1)   { Target.new(name: "foo", sendQueue: "alpha", receiveQueue: "beta") }
  let(:listener1) { Listener.new(target1) }
  let(:handler)   { StompHandlerNull.new }


  describe "#new" do

    it "should accept a queue name or a Target" do
      expect{ Listener.new }.to raise_error ArgumentError

      expect{ Listener.new target1 }.not_to raise_error
      expect{ Listener.new "alpha" }.not_to raise_error
    end

  end


  describe "#queue" do

    it "should return the queue name when object was given one" do
      expect( Listener.new("beta").queue ).to eq "beta"
    end

    it "should return Target.receive_queue when the object was given a target" do
      expect( Listener.new(target1).queue ).to eq target1.receive_queue
    end

  end


  describe "#stomp_handler" do

    it "allows you to insert a stomp_handler object for test purposes" do
      expect{ listener1.stomp_handler = handler }.not_to raise_exception
      expect( listener1.send :stomp_handler ).to eq handler
    end

    it "defaults to StompHandler if none is inserted" do
      expect( listener1.send(:stomp_handler).class ).to eq StompHandler
    end

  end


  describe "#consume_messages" do

    before do
      listener1.stomp_handler = handler
      handler.insert_fake "foo"
      handler.insert_fake "bar"
      handler.insert_fake "baz"
    end
     
    it "should yield each message on the queue" do
      expect{|b| listener1.consume_messages &b }.to yield_successive_args("foo", "bar", "baz")
    end
    
  end


  describe "#reply" do

    before do
      listener1.stomp_handler = handler
    end

    it "takes a queue name and a Message object" do
      expect{ listener1.reply        }.to raise_error ArgumentError
      expect{ listener1.reply("foo") }.to raise_error ArgumentError

      expect{ listener1.reply("alpha", "foo") }.not_to raise_error
    end

    it "sends the message to its reply_to queue" do
      expect( handler ).to receive(:send_message).with("beta", "bar").and_return("bar")

      listener1.reply("beta", "bar")
    end

  end


  describe "#quit" do
     
    it "calls StompHandler.stomp_disconnect" do
      listener1.stomp_handler = handler
      expect( handler ).to receive(:stomp_disconnect)
      listener1.quit
    end
      
    
  end
  

end

