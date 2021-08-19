require 'redis'
require 'json'

require_relative 'redis_handler'


module NebulousStomp

  ##
  # Behaves just like RedisHandler, except, does nothing and expects no
  # connection to Redis.
  #
  # This is hopefully useful for testing -- if only for testing of Nebulous.
  # 
  class RedisHandlerNull < RedisHandler

    attr_reader :fake_pair

    def initialize(connectHash={})
      super
      @fake_pair = {}
    end

    def insert_fake(key, value)
      @fake_pair = { key => value }
    end

    def connect
      @redis = true
      self
    end

    def quit
      @redis = nil
      self
    end
    
    def connected?
      @fake_pair != {}
    end

    def set(key, value, hash=nil) 
      insert_fake(key, value)
      "OK"
    end

    def del(key)
      x = @fake_pair.empty? ? 0 : 1
      @fake_pair = {}
      x
    end

    def get(key)
      @fake_pair.values.first
    end

  end 

  
end
