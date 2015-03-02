# coding: UTF-8

# Helper routines to deal with Redis, the key-value store

require 'redis'


module Nebulous


  # Deal with Redis
  # 
  class RedisHandler


    # Connect to the Redis key/value store. Raise NebulousError if connection
    # fails. Return the handle to the Redis connection object.
    #
    def self.connect
      redis = Redis.new( Param.get(:redisConnectHash) )

      redis.client.connect
      raise NebulousError, "Redis Connection failed" unless redis.connected?

      return redis
    end



  end 

  
end
