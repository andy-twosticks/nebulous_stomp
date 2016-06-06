require 'spec_helper'

include NebulousStomp

require 'nebulous_stomp/nebrequest'
require 'nebulous_stomp/message'
require 'nebulous_stomp/stomp_handler_null'
require 'nebulous_stomp/redis_handler_null'


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
    NebulousStomp.init( :stompConnectHash => @stomph, 
                   :redisConnectHash => @redish,
                   :messageTimeout   => 5,
                   :cacheTimeout     => 20 )

    NebulousStomp.add_target( :accord, 
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
      NebulousStomp.add_target( :dracula, 
                           :sendQueue      => "/queue/laplace.dev",
                           :receiveQueue   => "/queue/laplace.out" )

      expect( new_request('dracula', 'foo').mTimeout ).to eq(5)
    end

    it 'doesn\'t freak out if Nebulous is not "on"' do
      sh = StompHandlerNull.new({})

      expect{ NebRequest.new('accord','foo',nil,nil,sh,redis_h) }.
        not_to raise_exception

    end
      
  end
  ##


  describe "#clear_cache" do

    it "removes the redis cache for a single request" do
      redis_h.insert_fake('foo', 'bar')
      expect( redis_h ).to receive(:del).with( {"verb"=>"foo"}.to_json )

      new_request('accord', 'foo').clear_cache
    end

    it 'returns self' do
      r = new_request('accord', 'foo')
      expect( r.clear_cache ).to eq r
    end

    it 'doesn\'t freak out if Redis is not connected' do
      rh = RedisHandlerNull.new({})
      r = NebRequest.new( 'accord', 'foo', nil, nil, stomp_h, rh)

      expect{ r.clear_cache }.not_to raise_exception
      expect( r.clear_cache ).to eq r
    end

  end
  ##


  describe "#send_no_cache" do

    it "returns something from STOMP" do
      stomp_h.insert_fake( Message.from_parts('', '', 'foo', 'bar', 'baz') )
      request = new_request('accord', 'foo')
      response = request.send_no_cache

      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq('foo')
    end

    it 'returns a nebulous timeout if there is no response' do
      request = new_request('accord', 'foo')
      expect{ request.send_no_cache }.
        to raise_exception NebulousStomp::NebulousTimeout

    end

    it 'returns nil if Nebulous is disabled in the config' do
      sh = StompHandlerNull.new({})
      r = NebRequest.new('accord', 'foo', nil, nil, sh, redis_h)

      expect( r.send_no_cache ).to eq nil
    end

  end
  ##


  describe "#send" do

    it "returns a Message object from STOMP the first time" do
      stomp_h.insert_fake( Message.from_parts('', '', 'foo', 'bar', 'baz') )
      request = new_request('accord', 'foo')

      response = request.send
      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq('foo')
    end

    it "returns the answer from the cache the second time" do
      stomp_h.insert_fake( Message.from_parts('', '', 'foo', 'bar', 'baz') )
      redis_h.insert_fake('xxx', {'verb' => 'frog'}.to_json)

      # First time
      request = new_request('accord', 'foo')
      response = request.send

      # Second time
      request = new_request('accord', 'foo')
      response = request.send

      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq('frog')
    end

    it "allows you to specify a message timeout" do
      stomp_h.insert_fake( Message.from_parts('', '', 'foo', 'bar', 'baz') )
      request = new_request('accord', 'foo')

      expect{ request.send(3) }.not_to raise_exception
    end

    it "allows you to specify a message timeout & cache timeout" do
      stomp_h.insert_fake( Message.from_parts('', '', 'foo', 'bar', 'baz') )
      request = new_request('accord', 'foo')

      expect{ request.send(3, 120) }.not_to raise_exception
    end

    it 'returns a nebulous timeout if there is no response' do
      request = new_request('accord', 'foo')
      expect{ request.send }.to raise_exception NebulousStomp::NebulousTimeout
    end

    it 'still works if Redis is turned off in the config' do
      rh = RedisHandlerNull.new({})
      stomp_h.insert_fake( Message.from_parts('', '', 'foo', 'bar', 'baz') )
      r = NebRequest.new('accord', 'tom', nil, nil, stomp_h, rh)

      response = r.send
      expect( response ).to be_a NebulousStomp::Message
      expect( response.verb ).to eq('foo')
    end

    it 'returns nil if Nebulous is disabled in the config' do
      sh = StompHandlerNull.new({})
      r = NebRequest.new('accord', 'foo', nil, nil, sh, redis_h)

      expect( r.send ).to eq nil
    end

  end 
  ##


  describe '#redis_on?' do

    it 'is true if there is a redis connection hash' do
      request = new_request('accord', 'foo')
      expect( request.redis_on? ).to be_truthy
    end

    it 'is false if there is no redis connection hash' do
      rh = RedisHandlerNull.new({})
      r = NebRequest.new('accord', 'foo', nil, nil, stomp_h, rh)

      expect( r.redis_on? ).to be_falsy
    end

  end
  ##


  describe '#nebulous_on?' do

    it 'is true if there is a nebulous connection hash' do
      sh = StompHandlerNull.new({foo: 'bar'})
      r = NebRequest.new('accord', 'foo', nil, nil, sh, redis_h)

      expect( r.nebulous_on? ).to be_truthy
    end

    it 'is false if there is no nebulous connection hash' do
      sh = StompHandlerNull.new({})
      r = NebRequest.new('accord', 'foo', nil, nil, sh, redis_h)

      expect( r.nebulous_on? ).to be_falsy
    end

  end
  ##


end # of NebRequest

