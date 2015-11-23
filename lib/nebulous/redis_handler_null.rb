# coding: UTF-8

require 'redis'
require 'json'

require_relative 'redis_handler'


module Nebulous


  ##
  # Behaves just like RedisHandler, except, does nothing and expects no
  # connection to Redis.
  #
  # This is hopefully useful for testing -- if only for testing of Nebulous.
  # 
  class RedisHandlerNull < RedisHandler

    attr_reader :fake_pair


    def initialize(connectHash=nil)
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


    def set(key, value, hash=nil); insert_fake(key, value); end

    def del(key); @fake_pair = {}; end

    def get(key); @fake_pair.values.first; end


  end 

  
end
