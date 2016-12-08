require 'nebulous_stomp'
require 'nebulous_stomp/redis_helper'

require_relative 'gimme'


##
# These are the feature tests for Nebulous. They are not run when you type `rspec`; that only gets
# you the unit tests. You have to name this directory to run it: `rspec feature`.
#
# These tests require an actual, working STOMP server and an actual, working Redis server (and ones
# which you don't mind sending test messages to, at that). You should configure connection to this
# in features/connection.yaml; an example file is provided, features/connection_example.yaml.
#
describe 'stomp use cases' do

  def init_nebulous(configfile)
    config = YAML.load(File.open configfile)
    NebulousStomp.init config[:init]
    NebulousStomp.add_target("featuretest", config[:target] )
  end

  def new_request(verb)
    message = NebulousStomp::Message.new(verb: verb)
    NebulousStomp::Request.new("featuretest", message)
  end

  before(:all) do
    init_nebulous 'feature/connection.yaml'
    Thread.new{ Gimme.new("feature/connection.yaml").run; sleep 15 }
  end

  let(:hash) do
    { "verb"        => "foo", 
      "parameters"  => "bar", 
      "description" => "baz" }

  end

  let(:redis) { NebulousStomp::RedisHelper.new }


  ##
  # tests for the request-response use case - a server that consumes messages and responds with
  # other messages.
  #
  # Note that it's the Gimme class, in the thread above, that is actually doing the responding; we
  # just send a message to it and check the response.
  #
  describe "request-response" do

    it "can respond to a message with a success verb" do
      response = new_request("gimmesuccess").send_no_cache

      expect( response      ).to be_kind_of(NebulousStomp::Message)
      expect( response.verb ).to eq "success"
    end

    it "can respond to a message with an error verb" do
      response = new_request("gimmeerror").send_no_cache

      expect( response      ).to be_kind_of(NebulousStomp::Message)
      expect( response.verb ).to eq "error"
    end

    it "can respond to a message with a specific Protocol message" do
      response = new_request("gimmeprotocol").send_no_cache

      expect( response      ).to be_kind_of(NebulousStomp::Message)
      expect( response.verb ).to eq hash["verb"]
    end

    it "can respond to a message with a non-Protocol message" do
      message  = NebulousStomp::Message.new(verb: 'gimmemessage', contentType: 'text')
      response = NebulousStomp::Request.new("featuretest", message).send_no_cache

      expect( response      ).to be_kind_of(NebulousStomp::Message)
      expect( response.verb ).to be_nil
      expect( response.body ).to eq "weird message body"
    end

  end
  ##


  ##
  # Tests for the question-and-answer use case -- a process that sends a request to a
  # request-response server and waits for an answering response
  #
  describe "question-and-answer" do


    it "can send a JSON message and get a JSON response" do
      message  = NebulousStomp::Message.new(verb: 'gimmeprotocol', contentType: 'application/json')
      response = NebulousStomp::Request.new("featuretest", message).send_no_cache

      expect( response.content_type ).to eq 'application/json'
      expect( response.body ).to eq hash
      expect( response.stomp_body ).to eq hash.to_json
    end

    it "can send a text message and get a text response" do
      message  = NebulousStomp::Message.new(verb: 'gimmeprotocol', contentType: 'application/text')
      response = NebulousStomp::Request.new("featuretest", message).send_no_cache

      expect( response.content_type ).to eq 'application/text'
      expect( response.body ).to eq hash

      hash.each do |k,v|
        expect( response.stomp_body ).to match(/#{k}: *#{v}/)
      end
    end

    it "can cache a response in Redis" do

=begin
      message = NebulousStomp::Message.new(verb: 'gimmeprotocol', contentType: 'application/text')
      request = NebulousStomp::Request.new("featuretest", message)

      expect( 
      request.send
      expect( 
=end
    end

  end
  ##


  ##
  # Tests for the Redis use case -- user wants to access Redis so we grant them access through our
  # connection to it.
  #
  describe "redis" do

    it "can set a value in the store" do
      redis.del(:foo) rescue nil
      redis.set(:foo, "bar")
      expect( redis.get(:foo) ).to eq "bar"
    end

    it "can set a value in the store with a timeout"

    it "can get a value from the store" do
      redis.set(:foo, bar: "baz")
      expect( redis.get(:foo) ).to eq( {bar: "baz"} )
    end

    it "can remove a value from the store" 

  end
  ##

end

