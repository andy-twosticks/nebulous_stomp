require 'spec_helper'

require 'nebulous/stomp_handler'
require 'nebulous/message'

include Nebulous


describe 'StompHandler.body_to_hash' do

  def message(contentType, body)
    Stomp::Message.new( [ 'MESSAGE',
                          'destination:/queue/foo',
                          'message-id:999',
                          "content-type:#{contentType}",
                          '',
                          body ].join("\n") + "\0" )
  end


  it "raises an error unless it is given a STOMP message" do
    expect{ StompHandler.body_to_hash()      }.to raise_exception ArgumentError
    expect{ StompHandler.body_to_hash('foo') }.to raise_exception ArgumentError
  end

  context "when the content type is JSON" do

    it "parses the json" do
      body = {'one' => 'two', 'three' => [4,5]}
      msg = message('application/json', body.to_json)
      expect( StompHandler.body_to_hash(msg) ).to eq body

      body = [ {'one' => 2, 'three' => 4}, {'five' => 6} ]
      msg = message('application/json', body.to_json)
      expect( StompHandler.body_to_hash(msg) ).to eq body
    end

  end

  context "when the content type is not JSON" do

    it "assumes text lines in key:value format" do
      # Note that all values will be strings, and we can't support arrays.
      result = {'one' => 'two', 'three' => '4'}
      body = result.map{|k,v| "#{k}:#{v}" }.join("\n")
      msg = message('application/text', body )

      expect( StompHandler.body_to_hash(msg) ).to eq result
    end

  end

  it "returns a hash or an array of hashes" do
    # lets check some corner cases to ensure this
    msg = message('appplication/json', ''.to_json)
    expect( StompHandler.body_to_hash(msg) ).to eq({})

    msg = message('appplication/json', nil.to_json)
    expect( StompHandler.body_to_hash(msg) ).to eq({})

    msg = message('appplication/text', '')
    expect( StompHandler.body_to_hash(msg) ).to eq({})

    msg = message('appplication/text', nil)
    expect( StompHandler.body_to_hash(msg) ).to eq({})
  end


end
##


# with_timeout is kind of hard to test?


describe StompHandler do

  before do
    @stomph = { hosts: [{ login:    'guest',
                         passcode: 'guest',
                         host:     '10.0.0.150',
                         port:     61613,
                         ssl:      false }],
               reliable: false }

    @sh = StompHandler.new(@stomph)

=begin
    @redish = { host: '127.0.0.1',
                port: 6379,
                db:   0 }

    # The message that "stomp" returns to Nebulous. This has to be a real
    # Stomp::Message because (we assume) NebResponse uses class to tell what is
    # has been passed. Luckily it takes an actual frame; that seems unlikely to
    # change soon and is fairly stable for testing.
    # Note that we leave a %s here for the reply-to field...
    @msg = [ 'MESSAGE',
             'destination:/queue/foo',
             'message-id:999',
             'neb-in-reply-to:%s',
             '',
             'Foo' ].join("\n") + "\0"

    Nebulous.init( :stompConnectHash => @stomph, 
                   :redisConnectHash => @redish,
                   :messageTimeout   => 5,
                   :cacheTimeout     => 20 )

    Nebulous.add_target( :accord, 
                         :sendQueue      => "/queue/laplace.dev",
                         :receiveQueue   => "/queue/laplace.out",
                         :messageTimeout => 1 )

    # Wipe the whole darned Redis cache before every test.
    r = RedisHandler.connect
    r.flushall
    r.quit
=end
  end


  describe "#initialize" do

    it "takes an initialization hash" do
      expect{ StompHandler.new(foo: 'bar') }.not_to raise_exception
      expect{ StompHandler.new }.to raise_exception ArgumentError
    end

  end
  ##


  describe "#stomp_connect" do

    it "raises ConnectionError if it cannot connect to the STOMP server" do
      hash = @stomph.merge( hosts: {passcode:'flurb'} )
      sh = StompHandler.new(hash)

      expect{sh.stomp_connect}.to raise_exception Nebulous::ConnectionError
    end

    it "returns self" do
      expect(@sh.stomp_connect).to eq @sh
    end

    it "sets @client to an instance of STOMP::Client" do
      @sh.stomp_connect

      expect(@sh.client).to be_a Stomp::Client 
    end

    it "connects to the STOMP server" do
      # in passing we test #connected? -- there doesn't seem to be a way (or a
      # point) to test it seperately.
      
      @sh.stomp_connect
      expect( @sh ).to be_connected
    end

  end
  ##


  describe "#stomp_disconnect" do

    # in passing we test #connected? -- there doesn't seem to be a way (or a
    # point) to test it seperately.
    
    it "disconnects!" do
      @sh.stomp_connect
      @sh.stomp_disconnect

      expect( @sh ).not_to be_connected
    end

  end
  ##


  describe "#calc_reply_id" do

    it "raises an error if the client is not connected" do
      @sh.stomp_disconnect
      expect{ @sh.calc_reply_id }.to raise_exception Nebulous::ConnectionError
    end


    it "returns a unique string" do
      # I can't actually check that the string is unique, so this is kinda weak
      @sh.stomp_connect
      expect( @sh.calc_reply_id ).to respond_to :upcase
      expect( @sh.calc_reply_id.size ).to be > 12
    end
  end
  ##


  describe "send_message" do
    # We're kind of navel gazing here because send_message is just one line: a
    # call to @client.publish. Still, call it a warming up exercise....
    
    before do
      @client = double( Stomp::Client ).as_null_object
      @sh     = StompHandler.new(@stomph, @client)
      @sh.stomp_connect

      @mess = Nebulous::Message.from_parts(nil, nil, 'foo', nil, nil)
    end

    it "accepts a queue name and a Message" do
      expect{ @sh.send_message        }.to raise_exception ArgumentError
      expect{ @sh.send_message('foo') }.to raise_exception ArgumentError
      expect{ @sh.send_message(1,2,3) }.to raise_exception ArgumentError
      expect{ @sh.send_message('foo', 12) }.
        to raise_exception Nebulous::NebulousError

      expect{ @sh.send_message('foo', @mess) }.not_to raise_exception
    end

    it "returns the message" do
      expect( @sh.send_message('foo', @mess) ).to eq @mess
    end

    it "tries to publish the message" do
      expect(@client).to receive(:publish)
      @sh.send_message('foo', @mess)
    end

    it "tries to reconnect if the client is not connected" do
      @sh.stomp_disconnect

      expect(@client).to receive(:publish)
      @sh.send_message('foo', @mess)
      expect{ @sh.send_message('foo', @mess) }.not_to raise_exception
    end

  end
  ##


  describe "#listen" do

    before do
      @client = double( Stomp::Client ).as_null_object
      @sh     = StompHandler.new(@stomph, @client)
      @sh.stomp_connect

      @mess = Nebulous::Message.from_parts(nil, nil, 'foo', nil, nil)
    end

    it "tries to reconnect if the client is not connected" do
      @sh.stomp_disconnect
      expect(@client).to receive(:publish)
      expect{ @sh.listen('foo') }.not_to raise_exception
    end

    it "yields an instance of Message if it gets a response on the given queue"

    it "continues blocking after receiving a message"

  end
  ##


  describe "listen_with_timeout" do

    it "tries to reconnect if the client is not connected"

    it "yields an instance of Message if it gets a response on the given queue"

    it "stops after the first message"

    it "stops after a timeout"

  end
  ##


end 


=begin
  describe "#initialize" do

    it "raises an exception for a bad target" do
      expect{ NebRequest.new('badtarget', 'foo') }.to \
          raise_exception(NebulousError)

    end

    it "takes the timeout on the target over the default" do
      expect( NebRequest.new('accord', 'foo').mTimeout ).to eq(1)
    end

    it "falls back to the default if the timeout on the target is not set" do
      Nebulous.init( :stompConnectHash => @stomph, 
                     :redisConnectHash => @redish,
                     :messageTimeout   => 5,
                     :cacheTimeout     => 20 )

      Nebulous.add_target( :accord, 
                           :sendQueue      => "/queue/laplace.dev",
                           :receiveQueue   => "/queue/laplace.out" )

      expect( NebRequest.new('accord', 'foo').mTimeout ).to eq(5)
    end
      

  end


  context "if Nebulous gets no response" do
    before do
      # here we send an actual STOMP request to a non-existant target
      Param.add_target(:dummy, :sendQueue => "foo", :receiveQueue => "foo")
    end


    describe "#send_no_cache" do

      it "returns a NebulousTimeout" do
        expect{ NebRequest.new('dummy', 'foo').send_no_cache }.to \
            raise_exception(NebulousTimeout)

      end
    end

    describe "#send" do

      it "returns a NebulousTimeout" do
        expect{ NebRequest.new('dummy', 'foo').send }.to \
            raise_exception(NebulousTimeout)

      end
    end

  end


  context "if Nebulous gets a response" do
    before do
      # mock the whole STOMP process ... eek...
      @client = instance_double( Stomp::Client, 
                                 :close   => nil,
                                 :publish => nil,
                                 :'open?' => true )

      # We assume Nebulous wants session ID to make the replyID somehow
      # ...it doesn't have to; we don't enforce that.
      allow(@client).to receive_message_chain("connection_frame.headers").
          and_return({"session" => "123"})

    end


    describe "#send_no_cache" do

      it "returns a NebResponse object" do
        request = NebRequest.new('accord', 'foo', nil, nil, @client)
        msg = Stomp::Message.new( @msg % request.replyID )
        expect(@client).to receive(:subscribe).and_yield(msg)

        response = request.send_no_cache
        expect( response ).to be_a NebResponse
        expect( response.body ).to eq('Foo')
      end

      # I have no idea how to actual check that it *honours* the timeout...
      it "allows you to specify a message timeout" do
        request = NebRequest.new('accord', 'foo', nil, nil, @client)
        msg = Stomp::Message.new( @msg % request.replyID )
        allow(@client).to receive(:subscribe).and_yield(msg)

        expect{ response = request.send_no_cache(3) }.not_to raise_exception
      end

    end #send_no_cache


    describe "#send" do
      it "returns a NebResponse object from STOMP the first time" do
        request = NebRequest.new('accord', 'foo', nil, nil, @client)
        msg = Stomp::Message.new( @msg % request.replyID )
        expect(@client).to receive(:subscribe).and_yield(msg)

        response = request.send
        expect( response ).to be_a NebResponse
        expect( response.body ).to eq('Foo')
      end

      it "returns the answer from the cache the second time" do

        # First time
        request = NebRequest.new('accord', 'foo', nil, nil, @client)
        msg = Stomp::Message.new( @msg % request.replyID )
        expect(@client).to receive(:subscribe).and_yield(msg)

        response = request.send


        # Second time
        # Note, we actually need the Redis server to be up for this test to
        # work!
        request = NebRequest.new('accord', 'foo', nil, nil, @client)

        expect(@client).not_to receive(:subscribe)

        response = request.send
        expect( response ).to be_a NebResponse
        expect( response.body ).to eq('Foo')
      end

      it "allows you to specify a message timeout & cache timeout" do
        request = NebRequest.new('accord', 'foo', nil, nil, @client)
        msg = Stomp::Message.new( @msg % request.replyID )
        allow(@client).to receive(:subscribe).and_yield(msg)

        expect{ response = request.send(3) }.not_to raise_exception
        expect{ response = request.send(3, 120) }.not_to raise_exception
      end

    end # #send


    describe "#get_from_cache" do

      it "returns nil if there is no cached value" do
        req = NebRequest.new('accord', 'foo', nil, nil, @client)
        
        expect( req.get_from_cache ).to eq nil
      end

      it "returns the cached value if there is one" do
        req = NebRequest.new('accord', 'foo', nil, nil, @client)
        msg = Stomp::Message.new( @msg % req.replyID )
        allow(@client).to receive(:subscribe).and_yield(msg)

        req.send
        expect( req.get_from_cache ).not_to eq nil
      end


    end
          

    describe "#clear_cache" do
      before do
        msg  = [ 'foo', 'bar' ]
        @req = []

        2.times do
          r = NebRequest.new('accord', msg.shift, nil, nil, @client)
          m = Stomp::Message.new( @msg % r.replyID )
          allow(@client).to receive(:subscribe).and_yield(m)
          r.send
          @req << r
        end
      end

      it "removes the redis cache for a single request" do
        expect( @req[0].get_from_cache ).not_to eq nil
        expect( @req[1].get_from_cache ).not_to eq nil

        @req[0].clear_cache
        expect( @req[0].get_from_cache ).to eq nil
        expect( @req[1].get_from_cache ).not_to eq nil
      end

    end

  end # context "gets a response"
=end


