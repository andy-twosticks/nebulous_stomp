require_relative 'param'
require_relative 'redis_handler'


module NebulousStomp


  ##
  # A class to help out users who want to talk to Redis themselves
  # 
  class RedisHelper

    attr_writer :redis_handler

    def initialize
    end

    def set(key, value, timeout=nil)
      rtimeout = (Integer(timeout.to_s, 10) rescue nil)
      fail ArgumentError, "Timeout must be a number" if timeout && rtimeout.nil?
      ensure_connected

      if timeout
        redis_handler.set(key.to_s, value, rtimeout)
      else
        redis_handler.set(key.to_s, value)
      end
    end

    def get(key)
      ensure_connected
      json = redis_handler.get(key.to_s)
      json ? JSON.parse(json, symbolize_names: true) : nil

    rescue JSON::ParserError
      fail NebulousError, "Cannot parse stored JSON value '#{json}'"
    end

    def del(key)
      ensure_connected
      redis_handler.del(key.to_s)
    end

    def quit
      redis_handler.quit
    end

    private

    def redis_handler
      @redis_handler ||= RedisHandler.new(Param.get :redisConnectHash)
    end

    def ensure_connected
      redis_handler.connect unless redis_handler.connected?
    end

  end


end

