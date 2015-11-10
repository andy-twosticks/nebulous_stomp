require 'time'
require 'spec_helper'

require 'nebulous/stomp_handler'
require 'nebulous/message'

include Nebulous



describe StompHandler do

  def stomp_message(contentType, body, inReplyTo=nil)

    headers = { 'destination'  => '/queue/foo',
                'message-id'   => '999',
                'content-type' => contentType }

    headers['neb-in-reply-to'] = inReplyTo if inReplyTo

    mess = ['MESSAGE'] \
           + headers.map{|k,v| "#{k}:#{v}" } \
           << '' \
           << body

    Stomp::Message.new( mess.join("\n") + "\0" )
  end


  before do
    # Actually these are the real connection params, but we are going to stub,
    # so hopefully it doesn't matter.
    @stomph = { hosts: [{ login:    'guest',
                         passcode: 'guest',
                         host:     '10.0.0.150',
                         port:     61613,
                         ssl:      false }],
               reliable: false }

    @client = double( Stomp::Client ).as_null_object
    @sh     = StompHandler.new(@stomph, @client)
    
    # Attempt to duplicate anything in Stomp::Client that we might need.
    # This does the opposite of making me happy -- it's hella fragile, and
    # we're dealing with implementation details, in code we don't even
    # maintain! 
    # But. I don't know of another way to do this.
    conn = double("connection frame").as_null_object

    allow(@client).to receive(:connection_frame).and_return(conn)
    allow(@client).to receive_message_chain("connection_frame.headers").
       and_return({"session" => "123"})

  end


  describe 'StompHandler.body_to_hash' do

    it "raises an error unless it is given a STOMP message" do
      expect{ StompHandler.body_to_hash() }.to raise_exception ArgumentError

      expect{ StompHandler.body_to_hash('foo') }.
        to raise_exception ArgumentError

    end

    context "when the content type is JSON" do

      it "parses the json" do
        body = {'one' => 'two', 'three' => [4,5]}
        msg = stomp_message('application/json', body.to_json)
        expect( StompHandler.body_to_hash(msg) ).to eq body

        body = [ {'one' => 2, 'three' => 4}, {'five' => 6} ]
        msg = stomp_message('application/json', body.to_json)
        expect( StompHandler.body_to_hash(msg) ).to eq body
      end

    end

    context "when the content type is not JSON" do

      it "assumes text lines in key:value format" do
        # Note that all values will be strings, and we can't support arrays.
        result = {'one' => 'two', 'three' => '4'}
        body = result.map{|k,v| "#{k}:#{v}" }.join("\n")
        msg = stomp_message('application/text', body )

        expect( StompHandler.body_to_hash(msg) ).to eq result
      end

    end

    it "returns a hash or an array of hashes" do
      # lets check some corner cases to ensure this
      msg = stomp_message('appplication/json', ''.to_json)
      expect( StompHandler.body_to_hash(msg) ).to eq({})

      msg = stomp_message('appplication/json', nil.to_json)
      expect( StompHandler.body_to_hash(msg) ).to eq({})

      msg = stomp_message('appplication/text', '')
      expect( StompHandler.body_to_hash(msg) ).to eq({})

      msg = stomp_message('appplication/text', nil)
      expect( StompHandler.body_to_hash(msg) ).to eq({})
    end


  end
  ##


  describe "StompHandler.with_timeout" do

    it "should hang for the given timeout period" do
      start = Time.now
      StompHandler.with_timeout(2) do |r|
      end
      stop = Time.now

      expect(stop - start).to be_within(0.5).of(2)
    end

    it "should drop out of the block when given the signal" do
      start = Time.now
      StompHandler.with_timeout(2) do |r|
        r.signal
      end
      stop = Time.now

      expect(stop - start).to be < 0.5
    end
      
  end
  ##


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
      # Weeeeelllll -- actually... it isn't. It's the double.
      @sh.stomp_connect
      expect(@sh.client).to eq @client
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

    def run_listen(secs)
      got = nil

      @sh.listen('/queue/foo') do |m|
        got = m
      end
      sleep secs

      got
    end

    before do
      @msg = stomp_message( 'application/text', 
                            'verb:Foo', 
                            @client.calc_reply_id )

      @sh.stomp_connect
    end

    it "tries to reconnect if the client is not connected" do
      @sh.stomp_disconnect
      expect(@client).to receive(:publish)
      expect{ @sh.listen('foo') }.not_to raise_exception
    end

    it "yields a Message if it gets a response on the given queue" do
      allow(@client).to receive(:subscribe).and_yield(@msg)
      gotMessage = run_listen(1)

      expect(gotMessage).to be_a_kind_of Nebulous::Message
      expect( gotMessage.verb ).to eq 'Foo'
    end

    it "continues blocking after receiving a message" do
      # If it's still blocking, it should receive a second message
      msg2 = stomp_message( 'application/text', 
                            'verb:Bar', 
                            @client.calc_reply_id )

      allow(@client).to receive(:subscribe).
        and_yield(@msg).
        and_yield(msg2)

      gotMessage = run_listen(2)

      expect(gotMessage).to be_a_kind_of Nebulous::Message
      expect( gotMessage.verb ).to eq 'Bar'
    end

  end
  ##


  describe "listen_with_timeout" do

    def run_listen_with_timeout(secs)
      got = nil
      @sh.listen_with_timeout('/queue/foo', secs) do |m|
        got = m
      end

      got
    end

    before do
      @msg = stomp_message( 'application/text', 
                            'verb:Foo', 
                            @client.calc_reply_id )

      @sh.stomp_connect
    end

    it "tries to reconnect if the client is not connected" do
      @sh.stomp_disconnect
      expect(@client).to receive(:publish)
      expect{ @sh.listen_with_timeout('foo', 1) }.not_to raise_exception
    end

    it "yields a Message if it gets a response on the given queue" do
      allow(@client).to receive(:subscribe).and_yield(@msg)

      start = Time.now
      gotMessage = run_listen_with_timeout(2)
      stop = Time.now

      expect( gotMessage ).not_to be_nil
      expect( gotMessage ).to be_a_kind_of Nebulous::Message
      expect( gotMessage.verb ).to eq 'Foo'
      expect(stop - start).to be < 0.5
    end

    it "stops after the first message" do
      # The opposite of listen. We yield twice but expect the *first* message.
      msg2 = stomp_message( 'application/text', 
                            'verb:Bar', 
                            @client.calc_reply_id )

      allow(@client).to receive(:subscribe).
        and_yield(@msg).
        and_yield(msg2)

      gotMessage = run_listen_with_timeout(2)

      expect( gotMessage ).not_to be_nil
      expect( gotMessage ).to be_a_kind_of Nebulous::Message
      expect( gotMessage.verb ).to eq 'Foo'
    end

    it "stops after a timeout" do
      start = Time.now
      run_listen_with_timeout(2)
      stop = Time.now

      expect(stop - start).to be_within(0.5).of(2)
    end

  end
  ##


end 

