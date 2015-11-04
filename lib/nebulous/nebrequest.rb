# coding: UTF-8

require 'stomp'


module Nebulous


  ##
  # Class to handle requests and return a NebResponse
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
    
    # The STOMP client instance (dependancy injection for testing)
    attr_reader :client

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
    #   NebRequest.to_protocol(verb, params = nil, desc = nil) -> (String)
    #
    # Return a message body formatted for The Protocol.
    #
    # Parameters:
    #  verb      [String] the code for the action taken by the receiver
    #  params    [String] parameters for the action routine
    #  desc      [String] text for logs, users, etc
    #  (Returns) [String] Message formatted as JSON
    #
    def self.to_protocol(verb, params = nil, desc = nil)
      h = {verb: verb}
      h[:parameters]  = params unless params.nil?
      h[:description] = desc   unless desc.nil?

      h.to_json
    end


    ##
    # :call-seq:
    #   NebRequest.stomp_connect() -> (STOMP.client)
    #
    # Connect to the STOMP message server. Raise Nebulous::NebulousError if the
    # connection fails.
    #
    def self.stomp_connect
      client = Stomp::Client.new( Param.get(:stompConnectHash) )
      raise NebulousError, "Stomp Connection failed" unless client.open?

      conn = client.connection_frame()
      if conn.command == Stomp::CMD_ERROR
        raise NebulousError, "Connect Error: #{conn.body}" 
      end

      client
    end


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
    #
    def initialize(target, verb, params=nil, desc=nil, stompHandler=nil)

      # The target name -- should point to data in SwingShift::PARAMS
      @target = target                           

      targetHash = Param.get_target(@target)
      raise NebulousError, "Unknown target #{target}" if targetHash.nil?

      @verb, @params, @desc = verb, params, desc 

      @cTimeout  = Param.get(:cacheTimeout)
      @message   = NebRequest.to_protocol(verb, params, desc)
      @requestQ  = targetHash[:sendQueue]
      @responseQ = targetHash[:receiveQueue]
      @mTimeout  = targetHash[:messageTimeout] || Param.get(:messageTimeout)
      @stomp_handler = stompHandler 
      @replyID       = nil

      # Now we connect and set @replyID 
      neb_connect
    end


    ##
    # :call-seq:
    #   request.send_no_cache           -> (NebResponse)
    #   request.send_no_cache(mTimeout) -> (NebResponse)
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
      @stomp_handler.stomp_connect unless @stomp_handler.client.open?
      @replyID = @stomp_handler.calc_reply_id if @replyID.nil? 

      response = neb_qna(mTimeout)
      NebResponse.new(response) 

    ensure
      @stomp_handler.stomp_disconnect
    end


    ##
    # ::call-seq::
    #   request.send                    -> (NebResponse)
    #   request.send(mTimeout)          -> (NebResponse)
    #   request.send(mTimeout,cTimeout) -> (NebResponse)
    #
    # As send_nocache, but without not checking the cache :)
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

      redis = nil
      redis = RedisHandler::connect 

      found = redis.get(@message)
      return NebResponse.new(found) unless found.nil?

      # No answer in Redis -- ask Nebulous
      nebMess = send_no_cache(mTimeout)
      redis.set( @message, nebMess.to_cache, ex: cTimeout ) 

      nebMess

    ensure
      redis.quit unless redis.nil?
    end


    ##
    # :call-seq:
    #   request.get_from_cache -> (String || nil)
    #
    # Try to get the response from the cache. Returns the cached response, or
    # nil if not found
    #
    # *Send* doesn't use this because it wants the redis handle to set the cache
    # afterwards. The primary use for this is testing, but, who knows what
    # other use we might find.
    #
    def get_from_cache
      redis = nil
      redis = RedisHandler::connect 

      redis.get(@message)

    ensure
      redis.quit unless redis.nil?
    end


    ##
    # :call-seq:
    #   request.clear_cache -> self
    #
    # Clear the cache of responses to this request - just this request.
    #
    def clear_cache
      redis = nil
      redis = RedisHandler::connect 

      redis.del(@message)

      self

    ensure
      redis.quit unless redis.nil?
    end


    ##
    # :call-seq:
    #   request.neb_connect -> self
    #
    # Connect to STOMP and do initial setup
    # Called automatically by initialize, so probably useless to and end-user.
    #
    def neb_connect
      @stomp_handler ||= StompHandler.new( Param.get(:stompConnectHash) )
      @replyID = @stomp_handler.calc_replyID
      self
    end


    ##
    # :call-seq:
    #   request.redis_on? -> (boolean)
    #
    # Return true if Redis is turned on in the config
    #
    def redis_on?
      ! Param.get(:redisConnectHash).nil?
    end


    private

    
    ##
    # Send a message via STOMP and wait for a response
    # BAMF - need to rework StompHandler.nebmessage to get this to work?!
    #
    def neb_qna(mTimeout)

      headers = { "content-type" => "application/json",
                  "neb-reply-to" => @responseQ,
                  "neb-reply-id" => @replyID }
                  
      # Ensure the response queue exists
      @client.publish( @responseQ, "boo" ) 

      # Send the request
      @client.publish(@requestQ, @message, headers)

      # wait for the response
      response = nil

      StompHandler.with_timeout(mTimeout) do |x|

        @client.subscribe( @responseQ, {ack: "client-individual"} ) do |msg|

          if msg.body == "boo"
            @client.ack(msg)

          elsif msg.headers["neb-in-reply-to"] == @replyID
            response = msg
            @client.ack(msg)
            x.signal
          end

        end

      end # of with_timeout

      # And, finally...
      raise NebulousTimeout if response.nil?
      response

    end # of neb_qna


  end # of NebRequest


end

