require 'json'

require_relative 'param'
require_relative 'redis_handler'


module NebulousStomp


  ##
  # A class to help out users who want to talk to Redis themselves; the "Redis use case".
  #
  #    redis = NebulousStomp::RedisHelper.new
  #    
  #    redis.set(:thing, "thingy")
  #    redes.set(:gone_in_30_seconds, "thingy", 30)
  #    
  #    value = redis.get(:thing)
  #    
  #    redis.del(:thing)
  # 
  class RedisHelper

    # For testing only
    attr_writer :redis_handler

    ##
    # :call-seq: 
    # redis.set(key, value)
    # redis.set(key, value, timeout)
    #
    # Set a string value in the store.
    #
    def set(key, value, timeout=nil)
      rtimeout = (Integer(timeout.to_s, 10) rescue nil)
      fail ArgumentError, "Timeout must be a number" if timeout && rtimeout.nil?
      ensure_connected

      if timeout
        redis_handler.set(key.to_s, value, rtimeout)
      else
        redis_handler.set(key.to_s, value)
      end

      self
    end

    ##
    # :call-seq: 
    # redis.get(key) -> value
    #
    # Get a string value from the store. Return nil if there is none.
    #
    def get(key)
      ensure_connected
      redis_handler.get(key.to_s)
    end

    ##
    # :call-seq: 
    # redis.del(key)
    #
    # Remove a value from the store. Raise an exception if there is none.
    #
    def del(key)
      ensure_connected
      num = redis_handler.del(key.to_s)
      fail ArgumentError, "Unknown key, cannot delete" if num == 0
    end

    private

    def redis_handler
      @redis_handler ||= RedisHandler.new(Param.get :redisConnectHash)
    end

    def ensure_connected
      redis_handler.connect unless redis_handler.connected?
    end

    def parse(json)
      return nil if json.nil?
      JSON.parse(json, symbolize_names: true)
    rescue JSON::ParserError
      x = json.match /^"(.*)"/
      x ? x[1] : json
    end

  end # RedisHelper


end

