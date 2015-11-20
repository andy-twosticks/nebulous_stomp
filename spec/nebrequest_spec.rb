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

  let(:stomp_h) { StompHandlerNull.new(stomp_hash) }
  let(:redis_h) { RedisHandlerNull.new(redis_hash) }

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


  describe "#initialize" do

    it "raises an exception for a bad target" do
      expect{ new_request('badtarget', 'foo') }.
        to raise_exception(NebulousError)

    end

    it "takes the timeout on the target over the default" do
      expect( new_request('accord', 'foo').mTimeout ).to eq(1)
    end

    it "falls back to the default if the timeout on the target is not set" do
      Nebulous.add_target( :dracula, 
                           :sendQueue      => "/queue/laplace.dev",
                           :receiveQueue   => "/queue/laplace.out" )

      expect( new_request('dracula', 'foo').mTimeout ).to eq(5)
    end
      
  end
  ##


  context "if Nebulous gets no response" do

    describe "#send_no_cache" do

      it 'returns a nebulous timeout' do
        request = new_request('accord', 'foo')
        expect{ request.send_no_cache }.
          to raise_exception Nebulous::NebulousTimeout

      end

    end

    describe "#send" do

      it 'returns a nebulous timeout' do
        request = new_request('accord', 'foo')
        expect{ request.send }.to raise_exception Nebulous::NebulousTimeout
      end

    end

  end
  ##


  context "if Nebulous gets a response" do

    describe "#send_no_cache" do

      it "returns something from STOMP" do
        stomp_h.insert_fake('foo', 'bar', 'baz')
        request = new_request('accord', 'foo')
        response = request.send_no_cache

        expect( response ).to be_a Nebulous::Message
        expect( response.verb ).to eq('foo')
      end

    end
    ##


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
        redis_h.insert_fake('xxx', {'verb' => 'frog'}.to_json)

        # First time
        request = new_request('accord', 'foo')
        response = request.send

        # Second time
        request = new_request('accord', 'foo')
        response = request.send

        expect( response ).to be_a Nebulous::Message
        expect( response.verb ).to eq('frog')
      end

      it "allows you to specify a message timeout" do
        stomp_h.insert_fake('foo', 'bar', 'baz')
        request = new_request('accord', 'foo')

        expect{ request.send(3) }.not_to raise_exception
      end

      it "allows you to specify a message timeout & cache timeout" do
        stomp_h.insert_fake('foo', 'bar', 'baz')
        request = new_request('accord', 'foo')

        expect{ request.send(3, 120) }.not_to raise_exception
      end

    end 
    ##


    describe "#clear_cache" do

      it "removes the redis cache for a single request" do
        redis_h.insert_fake('foo', 'bar')
        expect( redis_h ).to receive(:del).with( {"verb"=>"foo"}.to_json )

        new_request('accord', 'foo').clear_cache
      end

    end
    ##


  end # context "gets a response"

end # of NebRequest

