# coding: UTF-8

# Helper routines to deal with Redis, the key-value store

require 'redis'


module Nebulous


  class RedisHandler


    # Connect to the Redis key/value store or throw an exception
    #
    def self.connect
      redis = Redis.new( PARAMS[:redis][:connect] )

      redis.client.connect
      raise NebulousError, "Redis Connection failed" unless redis.connected?

      return redis
    end


  end 

  
end
