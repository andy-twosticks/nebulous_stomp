require 'json'

require_relative '../nebulous_stomp'


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

    def initialize
      @param_hash = Param.get(:redisConnectHash)

      fail NebulousError, "NebulousStomp.init has not been called or Redis not configured" \
        if @param_hash.nil? || @param_hash.empty?

    end

    ##
    # :call-seq: 
    # redis.set(key, value)
    # redis.set(key, value, timeout)
    #
    # Set a value in the store.
    #
    def set(key, value, timeout=nil)
      rtimeout = (Integer(timeout.to_s, 10) rescue nil)
      rvalue   = value_to_json(value)
      fail ArgumentError, "Timeout must be a number" if timeout && rtimeout.nil?
      ensure_connected

      if timeout
        redis_handler.set(key.to_s, rvalue, ex: rtimeout)
      else
        redis_handler.set(key.to_s, rvalue)
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
      json_to_value(redis_handler.get key.to_s)
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

    def value_to_json(value)
      { value: value}.to_json
    end

    def json_to_value(json)
      return nil if json.nil?
      hash = JSON.parse(json, symbolize_names: true)

      hash.is_a?(Hash) ? hash[:value] : nil
    rescue JSON::ParserError
      return nil
    end

  end # RedisHelper


end

