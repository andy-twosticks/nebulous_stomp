# coding: UTF-8

require 'nebulous'

require_relative 'stomp_handler'
require_relative 'redis_handler'
require_relative 'message'


module Nebulous


  ##
  # Class to handle a request which returns a Message
  #
  # Note that this has changed since 0.1.0. The principal difference is we
  # return a Nebulous::Message; the NebResponse class no longer exists.
  #
  class NebRequest

    
    # The target name as set up by call to Nebulous::add_target
    attr_reader :target
    
    # The 'verb' part of the message
    attr_reader :verb      
    
    # The 'parameters' part of the message
    attr_reader :params    

    # The 'description' part of the message
    attr_reader :desc
    
    # The 'replyID' header to use in this message 
    attr_reader :replyID

    # Message timeout in seconds
    attr_reader :mTimeout

    # Cache timeout (fade and forget) in seconds
    attr_reader :cTimeout

    # The message
    attr_reader :message

    # The STOMP queue to send the request to
    attr_reader :requestQ

    # The STOMP queue to listen for responses on
    attr_reader :responseQ


    ##
    # :call-seq:
    #   NebRequest.new(target, verb) 
    #   NebRequest.new(target, verb, params) 
    #   NebRequest.new(target, verb, params, desc) 
    #
    # Create a new request. Raises Nebulous::NebulousError if anything goes
    # wrong.
    #
    # Parameters:
    #  target [Symbol] the target name to send the request to
    #  verb   [String] the 'verb' part of the message
    #  params [String] the 'parameters' part of the message
    #  desc   [String] the 'description' part of the message
    #  stompHandler    ONLY FOR TESTING
    #  redisHandler    ONLY FOR TESTING
    #
    def initialize( target, 
                    verb, 
                    params=nil, 
                    desc=nil, 
                    stompHandler=nil, 
                    redisHandler=nil )

      Nebulous.logger.debug(__FILE__) {"New NebRequest for verb #{verb}"}

      # The target name -- should point to data in the parameter hash
      @target = target                           

      targetHash = Param.get_target(@target)
      raise NebulousError, "Unknown target #{target}" if targetHash.nil?

      @verb, @params, @desc = verb, params, desc 

      @cTimeout  = Param.get(:cacheTimeout)
      @requestQ  = targetHash[:sendQueue]
      @responseQ = targetHash[:receiveQueue]
      @message   = Message.from_parts(@responseQ, nil, verb, params, desc)
      @mTimeout  = targetHash[:messageTimeout] || Param.get(:messageTimeout)
      @stomp_handler = stompHandler 
      @redis_handler = redisHandler 
      @replyID       = nil

      # Now we connect and set @replyID 
      neb_connect
    end


    ##
    # :call-seq:
    #     request.send_no_cache           -> (Message)
    #     request.send_no_cache(mTimeout) -> (Message)
    #
    # Send a request and return the response, without using the cache.
    #
    # Parameters:
    #  mTimeout [Fixnum] Message timout in seconds - defaults to @mTimeout
    #
    # Raises NebulousTimeout or NebulousError as necessary.
    #
    # Note that this routine completely ignores Redis. It doesn't just not
    # check the cache; it also doesn't update it.
    #
    def send_no_cache(mTimeout=@mTimeout)

      # If we've lost the connection then reconnect but *keep replyID*
      @stomp_handler.stomp_connect unless @stomp_handler.connected?
      @replyID = @stomp_handler.calc_reply_id if @replyID.nil? 

      neb_qna(mTimeout)

    ensure
      @stomp_handler.stomp_disconnect if @stomp_handler
    end


    ##
    # ::call-seq::
    #     request.send                    -> (Message)
    #     request.send(mTimeout)          -> (Message)
    #     request.send(mTimeout,cTimeout) -> (Message)
    #
    # As send_nocache, but without not using the cache :)
    #
    # Parameters:
    #  mTimeout  [Fixnum] Message timout in seconds - defaults to @mTimeout
    #  cTimeout  [Fixnum] Cache timout in seconds - defaults to @cTimeout
    #
    # Raises NebulousTimeout, NebulousError as necessary.
    #
    # We use Redis for the cache. This is possibly like using a sledgehammer
    # to crack a nut, but it certainly makes things very simple.
    #
    def send(mTimeout=@mTimeout, cTimeout=@cTimeout)
      return send_no_cache(mTimeout) unless redis_on?

      @redis_handler.connect unless @redis_handler.connected?

      found = @redis_handler.get(@message.protocol_json)
      return Message.from_cache(found) unless found.nil?


      # No answer in Redis -- ask Nebulous
      nebMess = send_no_cache(mTimeout)
      @redis_handler.set(@message.protocol_json, nebMess.to_cache, ex: cTimeout)

      nebMess

    ensure
      @redis_handler.quit if @redis_handler
    end


    ##
    # :call-seq:
    #   request.clear_cache -> self
    #
    # Clear the cache of responses to this request - just this request.
    #
    def clear_cache
      @redis_handler.connect unless @redis_handler.connected?

      @redis_handler.del(@message.protocol_json)

      self

    ensure
      @redis_handler.quit if @redis_handler
    end


    ##
    # :call-seq:
    #   request.redis_on? -> (boolean)
    #
    # Return true if Redis is turned on in the *config*
    #
    # (If you want to know if we are conected to Redis, try
    # `@redis_handler.connected?`)
    #
    def redis_on?
      @redis_handler.redis_on?
    end


    private


    ##
    # Connect to STOMP etc and do initial setup
    # Called automatically by initialize.
    #
    def neb_connect
      @redis_handler ||= RedisHandler.new( Param.get(:redisConnectHash) )
      @stomp_handler ||= StompHandler.new( Param.get(:stompConnectHash) )

      @stomp_handler.stomp_connect
      @replyID = @stomp_handler.calc_reply_id
      self
    end

    
    ##
    # Send a message via STOMP and wait for a response
    #
    # Note: this used to return a Stomp::Message, but now it returns a
    # Nebulous::Message.
    #
    def neb_qna(mTimeout)
      @stomp_handler.send_message(@requestQ, @message)

      response = nil
      @stomp_handler.listen_with_timeout(@responseQ, mTimeout) do |msg|
        response = msg
      end

      response
    end


  end # of NebRequest


end

