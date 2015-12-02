require 'spec_helper'

include Nebulous

require 'nebulous/nebrequest_null'

require 'nebulous/message'
#require 'nebulous/stomp_handler_null'
#require 'nebulous/redis_handler_null'

require 'pry' 


describe NebRequestNull do

  def new_request(target, verb, params=nil, desc=nil)
    NebRequestNull.new(target, verb, params, desc)
  end

  def disable(thing)
    Nebulous.init( :stompConnectHash => thing == :stomp ? {} : stomp_hash,
                   :redisConnectHash => thing == :redis ? {} : redis_hash,
                   :messageTimeout   => 5,
                   :cacheTimeout     => 20 )

    Nebulous.add_target( :accord, 
                         :sendQueue      => "/queue/laplace.dev",
                         :receiveQueue   => "/queue/laplace.out",
                         :messageTimeout => 1 )
  end

  let(:stomp_hash) do
    { hosts: [{ login:    'guest',
                passcode: 'guest',
                host:     '10.0.0.150',
                port:     61613,
                ssl:      false }],
      reliable: false }

  end

  let(:redis_hash) { {host: '127.0.0.1', port: 6379, db: 0} }

  before do
    disable(:nothing)
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

    it 'doesn''t freak out if Nebulous is not "on"' do
      disable(:stomp)
      expect{ NebRequestNull.new('accord', 'foo', nil, nil) }.
        not_to raise_exception

    end
      
  end
  ##


  describe "#clear_cache" do

    it 'returns self' do
      r = new_request('accord', 'foo')
      expect( r.clear_cache ).to eq r
    end

    it 'doesn''t freak out if Redis is not connected' do
      disable(:redis)
      r = NebRequestNull.new( 'accord', 'foo', nil, nil)

      expect{ r.clear_cache }.not_to raise_exception
      expect( r.clear_cache ).to eq r
    end

  end
  ##


  describe "#send_no_cache" do

    it "returns something from STOMP" do
      request = new_request('accord', 'foo')
      request.insert_fake_stomp('foo', 'bar', 'baz')
      response = request.send_no_cache

      expect( response ).to be_a Nebulous::Message
      expect( response.verb ).to eq('foo')
    end

    it 'returns a nebulous timeout if there is no response' do
      request = new_request('accord', 'foo')
      expect{ request.send_no_cache }.
        to raise_exception Nebulous::NebulousTimeout

    end

    it 'returns nil if Nebulous is disabled in the config' do
      disable(:stomp)
      r = new_request('accord', 'foo')

      expect( r.send_no_cache ).to eq nil
    end

  end
  ##


  describe "#send" do

    it "returns a Message object from STOMP the first time" do
      request = new_request('accord', 'foo')
      request.insert_fake_stomp('foo', 'bar', 'baz')

      response = request.send
      expect( response ).to be_a Nebulous::Message
      expect( response.verb ).to eq('foo')
    end

    it "returns the answer from the cache if there is one" do
      request = new_request('accord', 'foo')
      request.insert_fake_stomp('foo', 'bar', 'baz')
      request.insert_fake_redis('xxx', {'verb' => 'frog'}.to_json)
      response = request.send

      expect( response ).to be_a Nebulous::Message
      expect( response.verb ).to eq('frog')
    end

    it "allows you to specify a message timeout" do
      request = new_request('accord', 'foo')
      request.insert_fake_stomp('foo', 'bar', 'baz')

      expect{ request.send(3) }.not_to raise_exception
    end

    it "allows you to specify a message timeout & cache timeout" do
      request = new_request('accord', 'foo')
      request.insert_fake_stomp('foo', 'bar', 'baz')

      expect{ request.send(3, 120) }.not_to raise_exception
    end

    it 'returns a nebulous timeout if there is no response' do
      request = new_request('accord', 'foo')
      expect{ request.send }.to raise_exception Nebulous::NebulousTimeout
    end

    it 'still works if Redis is turned off in the config' do
      disable(:redis)
      r = new_request('accord', 'tom')
      r.insert_fake_stomp('foo', 'bar', 'baz')

      response = r.send
      expect( response ).to be_a Nebulous::Message
      expect( response.verb ).to eq('foo')
    end

    it 'returns nil if Nebulous is disabled in the config' do
      disable(:stomp)
      r = new_request('accord', 'foo')

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
      disable(:redis)
      r = new_request('accord', 'foo')
      expect( r.redis_on? ).to be_falsy
    end

  end
  ##


  describe '#nebulous_on?' do

    it 'is true if there is a nebulous connection hash' do
      r = new_request('accord', 'foo')
      expect( r.nebulous_on? ).to be_truthy
    end

    it 'is false if there is no nebulous connection hash' do
      disable(:stomp)
      r = new_request('accord', 'foo')
      expect( r.nebulous_on? ).to be_falsy
    end

  end
  ##

end # of NebRequestNull

