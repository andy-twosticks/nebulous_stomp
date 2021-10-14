require "stomp"
require "nebulous_stomp/request"
require "nebulous_stomp/stomp_handler_null"
require "nebulous_stomp/redis_handler_null"

include NebulousStomp


describe Request do

  def new_request(target, message)
    r = Request.new(target, message)
    r.stomp_handler = @stomp_handler
    r.redis_handler = @redis_handler
    r
  end

  def turn_off_redis
    Param.set(:stompConnectHash => @stomp_hash, :redisConnectHash => nil)
    @redis_handler = nil
  end

  def turn_off_nebulous
    Param.set(:stompConnectHash => nil, :redisConnectHash => @redis_hash)
    @nebulous_handler = nil
  end

  let(:target1) do 
    Target.new( name:         "target1", 
                sendQueue:    "/queue/foo", 
                receiveQueue: "/queue/bar" )

  end

  let(:target2) do 
    Target.new( name:          "target1", 
                sendQueue:     "/queue/foo", 
                receiveQueue:  "/queue/bar",
                messageTimeout: 1 )

  end

  let(:message1) do
    Message.new( verb: "boop", params: "booper", desc: "booping")
  end

  let(:message2) do
    Message.new( verb: "parp", params: "parper", desc: "parping", replyTo: "parps" )
  end

  let(:request1) do
    request = new_request(target1, message1)
    @stomp_handler.insert_fake Message.new(inReplyTo: request.message.reply_id, verb: "foo")
    request
  end

  let(:request2) do
    request = new_request(target1, message1)
    @stomp_handler.insert_fake Message.new(inReplyTo: request.message.reply_id, stompBody: "1 \xa2 2")
    request
  end

  before(:each) do
    # We shouldn't be calling Stomp or Redis in these tests. If we are, this will give us an error.
    fakestomp = double("fakestomp")
    fakeredis = double("fakeredis")
    allow( Stomp::Connection ).to receive(:new).and_return( fakestomp )
    allow( Redis             ).to receive(:new).and_return( fakeredis )

    @stomp_hash = { hosts: [{ login:    'guest',
                              passcode: 'guest',
                              host:     '10.0.0.150',
                              port:     61613,
                              ssl:      false }],
                    reliable: false }

    @redis_hash = {host: '127.0.0.1', port: 6379, db: 0}

    @stomp_handler = StompHandlerNull.new(@stomp_hash)
    @redis_handler = RedisHandlerNull.new(@redis_hash)

    NebulousStomp.init( :stompConnectHash => @stomp_hash, 
                        :redisConnectHash => @redis_hash,
                        :messageTimeout   => 5,
                        :cacheTimeout     => 20 )

    NebulousStomp.add_target( :accord, 
                              :sendQueue      => "/queue/laplace.dev",
                              :receiveQueue   => "/queue/laplace.out",
                              :messageTimeout => 1 )

  end


  describe "Request.new" do
     
    it "requires a Target or a target name as the first parameter" do
      expect{ Request.new(nil, message1) }.to raise_error ArgumentError
      expect{ Request.new(14,  message1) }.to raise_error ArgumentError

      expect{ Request.new(target1,  message1) }.not_to raise_error
      expect{ Request.new("accord", message1) }.not_to raise_error
    end

    it "requires a Message as the second parameter" do
      expect{ Request.new(target1, :foo) }.to raise_error ArgumentError
      expect{ Request.new(target1, nil)  }.to raise_error ArgumentError

      expect{ Request.new(target1, message1) }.not_to raise_error
    end

    it "expects the message parameter to follow The Protocol" do
      m = Message.new(body: "blarg")
      expect{ Request.new(target1, m) }.to raise_error ArgumentError
    end

    it "stores the given message if it has a reply_to" do
      expect( Request.new(target1, message2).message ).to eq message2
    end

    it "stores a new message with a reply_to from the target if the given one is missing it" do
      r = new_request(target1, message1)
      expect( r.message ).not_to eq message1
      expect( r.message.verb     ).to eq message1.verb
      expect( r.message.params   ).to eq message1.params
      expect( r.message.desc     ).to eq message1.desc
      expect( r.message.reply_to ).to eq target1.send_queue
    end

  end # of Request.new


  describe "#message_timeout" do

    it "takes the timeout on the target over the default" do
      r = new_request(target2, message1)
      expect( r.message_timeout ).to eq 1
    end

    it "falls back to the default if the timeout on the target is not set" do
      r = new_request(target1, message1)
      expect( r.message_timeout ).to eq 5
    end

  end # of #message_timeout


  describe "#cache_timeout" do

    it "returns the cache timeout value stored in Param" do
      r = new_request(target1, message1)
      expect( r.cache_timeout ).to eq 20
    end

  end # of #cache_timeout


  describe "#send_no_cache" do

    it "returns a response from StompHandler" do
      response = request1.send_no_cache
      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq "foo"
    end

    it "raises a NebulousTimeout if there is no response" do
      request = new_request('accord', message1)

      # if we don't give StompHandlerNull a response to send, request should time out
      expect{ request.send_no_cache }.to raise_exception NebulousStomp::NebulousTimeout
    end

    it "returns nil if Nebulous is disabled in the config" do
      turn_off_nebulous
      request = new_request('accord', message1)
      expect( request.send_no_cache ).to be_nil
    end

    it "encodes the response message body from Stomp if the encoding was not valid" do
      response = request2.send_no_cache
      expect( response.body ).to be_valid_encoding
    end

  end # of #send_no_cache
  

  describe "#clear_cache" do

    it "removes the redis cache for a single request" do
      @redis_handler.insert_fake('foo', 'bar')
      expect( @redis_handler ).to receive(:del).with( message1.protocol_json )

      new_request(target1, message1).clear_cache
    end

    it "returns self" do
      @redis_handler.insert_fake('foo', 'bar')
      r = new_request(target1, message1)
      
      expect( r.clear_cache ).to eq r
    end

    it "doesn't freak out if Redis is not connected" do
      turn_off_redis
      r = new_request(target1, message1)
      expect{ r.clear_cache }.not_to raise_exception
      expect( r.clear_cache ).to eq r
    end

  end # of #clear_cache

  
  describe "#send" do

    it "returns a Message object from STOMP the first time" do
      response = request1.send
      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq "foo"
    end

    it "returns the answer from the cache the second time" do
      @stomp_handler.insert_fake Message.new(verb: "foo")
      @redis_handler.insert_fake( "xxx", {'verb' => 'frog'}.to_json )

      # First time
      request = new_request(target1, message1)
      response = request.send

      # Second time
      request = new_request(target1, message1)
      response = request.send

      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq "frog"
    end

    it "writes the response to the cache as JSON" do
      response = request1.send
      expect{ JSON.parse @redis_handler.fake_pair.values.first }.not_to raise_exception
    end

    it "allows you to specify a message timeout" do
      expect{ request1.send(3) }.not_to raise_exception
    end

    it "allows you to specify a message timeout & cache timeout" do
      expect{ request1.send(3, 120) }.not_to raise_exception
    end

    it "raises a NebulousTimeout if there is no response" do
      request = new_request(target1, message1)
      expect{ request.send }.to raise_exception NebulousStomp::NebulousTimeout
    end

    it "still works if Redis is turned off in the config" do
      turn_off_redis
      response = request1.send
      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq "foo"
    end

    it "returns nil if Nebulous is disabled in the config" do
      turn_off_nebulous
      request = new_request(target1, message1)
      expect( request.send ).to be_nil
    end

    it "encodes the response message body from Stomp if the encoding was not valid" do
      response = request2.send
      expect( response.body ).to be_valid_encoding
    end

  end # of #send
  

end

