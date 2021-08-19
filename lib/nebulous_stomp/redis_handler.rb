require 'redis'


module NebulousStomp


  ##
  # A class to deal with talking to Redis via the Redis gem
  #
  # You shouldn't need to instantiate this yourself. If you want to use NebulousStomp to talk to
  # redis directly, try NebulousStomp::RedisHelper.
  # 
  class RedisHandler

    # This is most likely useless to anything except spec/redis_handler_spec -- at least, I hope
    # so...
    attr_reader :redis

    ##
    # Initialise an instance of the handler by passing it the connection hash
    #
    # If no hash is passed, we try and get it from Nebulous::Params
    #
    # We use the optional testRedis parameter to mock connections to Redis, for testing. It's
    # probably of no use to anyone else.
    #
    def initialize(connectHash=nil, testRedis=nil)
      @redis_hash = connectHash ? connectHash.dup : nil
      @test_redis = testRedis 
      @redis      = nil
    end

    ##
    # Connect to the Redis key/value store. Raise Nebulous error if connection fails. 
    #
    def connect
      @redis = @test_redis || Redis.new(@redis_hash.dup)

      @redis.client.connect
      fail ConnectionError, "Redis Connection failed" unless @redis.connected?

      self
    rescue => err
      raise ConnectionError, err.to_s
    end

    ##
    # :call-seq:
    #   handler.connected? -> (boolean)
    #
    # Call @redis.quit if appropriate; raise nothing if we are not connected etc
    #
    def quit
      @redis.quit if connected?
      @redis = nil
      self
    end

    ##
    # return whether we are connected to Redis.
    #
    def connected?
      @redis && @redis.connected?
    end

    ##
    # :call-seq:
    #   handler.redis_on? -> (boolean)
    #
    # Return whether the Redis is turned "on" in the connect hash, the config file.
    #
    # The rest of nebulous should just let RedisHandler worry about this detail.
    #
    def redis_on?
      @redis_hash && !@redis_hash.empty?
    end

    ##
    # Cover all the other methods on @redis that we are basically forwarding to it. I could use
    # Forwardable here -- except that would not allow us to raise Nebulous::ConnectionError if
    # @redis.nil?
    #
    # Possible candidates for future inclusion: exists, expire, ping
    #
    def method_missing(meth, *args)
      super unless [:set,:get,:del].include?(meth)
      fail ConnectionError, "Redis not connected, sent #{meth}" unless connected?

      @redis.__send__(meth, *args)
    end

  end # RedisHandler

  
end
