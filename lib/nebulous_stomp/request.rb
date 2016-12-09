require_relative 'stomp_handler'
require_relative 'redis_handler'
require_relative 'message'
require_relative 'target'


module NebulousStomp


  ##
  # Class to handle a request which returns a Message; the Question-Answer use case.
  #
  #     message   = NebulousStomp::Message.new(verb: "ping")
  #     request   = NebulousStomp::Request.new(:target1, message)
  #     response1 = request.send
  #
  # This replaces the old NebRequest class; it's much more clearly a wrapper for a Message, now.
  #
  class Request

    attr_reader :target, :message

    # If you are testing you can write these with, for example, a StompHandlerNull object
    attr_writer :stomp_handler, :redis_handler

    ##
    # :call-seq:
    #   Request.new(target, message) 
    #
    # Pass either a Target or a target name; and a Message (which has a verb)
    #
    def initialize(target, message)
      @target  = parse_target(target)
      @message = parse_message(message, @target)

      # Get a connection to StompHandler ASAP and set reply_id on @message
      ensure_stomp_connected if NebulousStomp.on?
    end

    ##
    # :call-seq:
    #     request.send_no_cache           -> (Message)
    #     request.send_no_cache(mtimeout) -> (Message)
    #
    # Send a request and return the response, without using the cache.
    #
    # Parameters:
    #  mTimeout [Fixnum] Message timout in seconds - defaults to #message_timeout
    #
    # Raises ArgumentError, NebulousTimeout or NebulousError as necessary.
    #
    # Note that this routine completely ignores Redis. It doesn't just not check the cache; it also
    # doesn't update it.
    #
    def send_no_cache(mtimeout=message_timeout)
      return nil unless NebulousStomp.on?
      ensure_stomp_connected
      neb_qna(mtimeout)
    ensure
      stomp_handler.stomp_disconnect
    end

    ##
    # :call-seq:
    #     request.send                    -> (Message)
    #     request.send(mTImeout)          -> (Message)
    #     request.send(mtimeout,ctimeout) -> (Message)
    #
    # As send_nocache, but without not using the cache :)
    #
    # Parameters:
    #  mtimeout Message timout in seconds - defaults to @mTimeout
    #  ctimeout Cache timout in seconds - defaults to @cTimeout
    #
    # Raises ArgumentError, NebulousTimeout, NebulousError as necessary.
    #
    def send(mtimeout=message_timeout, ctimeout=cache_timeout)
      return nil unless NebulousStomp.on?
      return send_no_cache(mtimeout) unless NebulousStomp.redis_on?
      ensure_redis_connected

      if (mess = cache_read).nil?
        mess = send_no_cache(mtimeout)
        cache_write(mess, ctimeout)
      end

      mess
    ensure
      redis_handler.quit
    end

    ##
    # :call-seq:
    #   request.clear_cache -> self
    #
    # Clear the cache of responses to this request - just this request.
    #
    def clear_cache
      return self unless NebulousStomp.redis_on?
      ensure_redis_connected
      redis_handler.del(@message.protocol_json)
      self
    ensure
      redis_handler.quit
    end

    ##
    # Returns the default message timeout
    #
    def message_timeout
      @target.message_timeout || Param.get(:messageTimeout)
    end

    ##
    # Returns the default cache timeout
    #
    def cache_timeout
      Param.get(:cacheTimeout)
    end

    private

    def stomp_handler
      @stomp_handler ||= StompHandler.new(Param.get :stompConnectHash)
    end

    def redis_handler
      @redis_handler ||= RedisHandler.new(Param.get :redisConnectHash)
    end

    ##
    # Helper routine for initialize
    #
    def parse_message(message, target)
      fail ArgumentError, "Message was not a Message"    unless message.is_a? Message
      fail ArgumentError, "Message does not have a verb" unless message.verb

      new_message = ->(h){ Message.new(message.to_h.merge h) }
      message.reply_to ? message : new_message.(replyTo: target.send_queue)
    end

    ##
    # Helper routine for initialize
    #
    def parse_target(target)
      t = target.is_a?(Target) ? target : Param.get_target(target)
      fail ArgumentError, "Target was not a Target or a target name" unless t
      t
    end
    
    ##
    # Connect to Stomp
    # If we've lost the connection then reconnect but *keep replyID*
    #
    def ensure_stomp_connected
      stomp_handler.stomp_connect unless stomp_handler.connected?
      @message.reply_id = stomp_handler.calc_reply_id if @message.reply_id.nil? 
    end

    ##
    # Connect to Redis
    #
    def ensure_redis_connected
      redis_handler.connect unless redis_handler.connected?
    end

    ##
    # Send a message via STOMP and wait for a response
    #
    def neb_qna(mTimeout)
      stomp_handler.send_message(@target.receive_queue, @message)

      response = nil
      stomp_handler.listen_with_timeout(@target.send_queue, mTimeout) do |msg|
        if @message.reply_id && msg.in_reply_to != @message.reply_id
          false
        else
          response = msg
          true
        end
      end

      response
    end

    ##
    # Read from the Redis cache
    #
    def cache_read
      found = redis_handler.get(@message.protocol_json)
      found.nil? ? nil : Message.from_cache(found)
    end

    ##
    # Write to the Redis cache
    #
    def cache_write(response, timeout)
      redis_handler.set(@message.protocol_json, response.to_h, ex: timeout)
    end

  end # Request


end

