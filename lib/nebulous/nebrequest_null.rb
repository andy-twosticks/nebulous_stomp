# coding: UTF-8

require 'nebulous'

require_relative 'nebrequest'
require_relative 'stomp_handler_null'
require_relative 'redis_handler_null'


module Nebulous


  ## 
  # Class to fake a NebRequest
  #
  class NebRequestNull < NebRequest

    def initialize( target, verb, params=nil, desc=nil )
      sh = StompHandlerNull.new( Param.get(:stompConnectHash) )
      rh = RedisHandlerNull.new( Param.get(:redisConnectHash) )
      super(target, verb, params, desc, sh, rh)
    end


    def insert_fake_stomp(verb, params, desc)
      @stomp_handler.insert_fake(verb, params, desc)
    end


    def insert_fake_redis(key, value)
      @redis_handler.insert_fake(key, value)
    end


  end 


end

