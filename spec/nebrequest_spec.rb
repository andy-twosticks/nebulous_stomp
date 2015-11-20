require 'spec_helper'

include Nebulous

require 'nebulous/nebrequest'
require 'nebulous/message'
require 'nebulous/stomp_handler_null'
require 'nebulous/redis_handler_null'

require 'pry' 


describe NebRequest do

  let(:stomp_hash) do
    { hosts: [{ login:    'guest',
                passcode: 'guest',
                host:     '10.0.0.150',
                port:     61613,
                ssl:      false }],
      reliable: false }

  end

  let(:redis_hash) { {host: '127.0.0.1', port: 6379, db: 0} }

  let(:stomp_h) { StompHandlerNull.new }
  let(:redis_h) { RedisHandlerNull.new }

=begin
  let(:msg1) do 
    Nebulous::Message.from_parts('/queue/1', nil, 'foo', 'bar', 'baz')
  end
=end

  def new_request(target, verb, params=nil, desc=nil)
    NebRequest.new(target, verb, params, desc, stomp_h, redis_h)
  end

  before do
    Nebulous.init( :stompConnectHash => @stomph, 
                   :redisConnectHash => @redish,
                   :messageTimeout   => 5,
                   :cacheTimeout     => 20 )

    Nebulous.add_target( :accord, 
                         :sendQueue      => "/queue/laplace.dev",
                         :receiveQueue   => "/queue/laplace.out",
                         :messageTimeout => 1 )

  end



=begin
  before do
    @stomph = { hosts: [{ login:    'guest',
                         passcode: 'guest',
                         host:     '10.0.0.150',
                         port:     61613,
                         ssl:      false }],
               reliable: false }

    @redish = { host: '127.0.0.1',
                port: 6379,
                db:   0 }

    @client = StompHandlerNull.new
    @client.insert_fake('foo', 'bar', 'baz')


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
  end
=end


  describe "#initialize" do

    it "raises an exception for a bad target" do
      expect{ new_request('badtarget', 'foo') }.
        to raise_exception(NebulousError)

    end

    it "takes the timeout on the target over the default" do
      expect( new_request('accord', 'foo').mTimeout ).to eq(1)
    end

    it "falls back to the default if the timeout on the target is not set" do
      Nebulous.init( :stompConnectHash => stomp_hash, 
                     :redisConnectHash => redis_hash,
                     :messageTimeout   => 5,
                     :cacheTimeout     => 20 )

      Nebulous.add_target( :accord, 
                           :sendQueue      => "/queue/laplace.dev",
                           :receiveQueue   => "/queue/laplace.out" )

      expect( new_request('accord', 'foo').mTimeout ).to eq(5)
    end
      

  end


  context "if Nebulous gets no response" do

    describe "#send_no_cache" do #bamf
    end

    describe "#send" do #bamf
    end

  end


  context "if Nebulous gets a response" do

    describe "#send_no_cache" do

      it "returns something from STOMP" do
        stomp_h.insert_fake('foo', 'bar', 'baz')
        request = new_request('accord', 'foo')
        response = request.send_no_cache

        expect( response ).to be_a Nebulous::Message
        expect( response.verb ).to eq('foo')
      end

    end #send_no_cache


    describe "#send" do
      it "returns a Message object from STOMP the first time" do
        stomp_h.insert_fake('foo', 'bar', 'baz')
        request = new_request('accord', 'foo')

        response = request.send
        expect( response ).to be_a Nebulous::Message
        expect( response.verb ).to eq('foo')
      end

      it "returns the answer from the cache the second time" do
        stomp_h.insert_fake('foo', 'bar', 'baz')
        redis_h.insert_fake('frog', 'star')

        # First time
        request = new_request('accord', 'foo')
        response = request.send

        expect( response ).to be_a Nebulous::Message
        expect( response.verb ).to eq('foo')

        # Second time
        request = new_request('accord', 'foo')
        response = request.send

        expect( response ).to be_a Nebulous::Message
        expect( response.verb ).to eq('frog')
      end

      it "allows you to specify a message timeout & cache timeout" do
        request = new_request('accord', 'foo')
        msg = Stomp::Message.new( @msg % request.replyID )
        allow(@client).to receive(:subscribe).and_yield(msg)

        expect{ response = request.send(3) }.not_to raise_exception
        expect{ response = request.send(3, 120) }.not_to raise_exception
      end

    end # #send


    describe "#get_from_cache" do

      it "returns nil if there is no cached value" do
        req = new_request('accord', 'foo')
        expect( req.get_from_cache ).to eq nil
      end

      it "returns the cached value if there is one" do
        req = new_request('accord', 'foo')
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
          r = new_request('accord', msg.shift)
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

end # of NebRequest

