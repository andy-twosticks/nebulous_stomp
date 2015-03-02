# coding: UTF-8

require 'stomp'


module Nebulous


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


    # Create a new request. Raises Nebulous::NebulousError if anything goes
    # wrong.
    #
    # Parameters:
    #  target [Symbol] the target name to send the request to
    #  verb   [String] the 'verb' part of the message
    #  params [String] the 'parameters' part of the message
    #  desc   [String] the 'description' part of the message
    #  client          ONLY FOR TESTING
    #
    def initialize(target, verb, params=nil, desc=nil, client=nil)

      # The target name -- should point to data in SwingShift::PARAMS
      @target = target                           

      # The triumverate for The Protocol
      @verb, @params, @desc = verb, params, desc 

      # Nebulous response timeout; time for a cache entry to expire
      @mTimeout = Param.get(:messageTimeout)
      @cTimeout = Param.get(:cacheTimeout)

      # The request message body
      @message = NebRequest.to_protocol(verb, params, desc)

      # The queues to send and listen on
      @requestQ, @responseQ = NebRequest.parse_config_for(target)

      # STOMP::Client instance - *only* passed in during testing
      @client = client

      # The "unique ID" attached to the message
      @replyID = nil

      # Now we connect and set @replyID 
      neb_connect
    end


    # :call-seq:
    # NebRequest.to_protocol(verb, params = nil, desc = nil) -> (String)
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

      return h.to_json
    end


    # :call-seq:
    # NebRequest.parse_config_for(target) -> (requestQueue, ResponseQueue)
    #
    # Return the Nebulous queues for a target. Raise Nebulous::NebulousError if
    # they are missing.
    #
    def self.parse_config_for(target)
      targetHash = Param.get_target(target)

      requestQ  = targetHash[:sendQueue]
      responseQ = targetHash[:receiveQueue]

      return requestQ, responseQ
    end


    # :call-seq:
    # NebRequest.stomp_connect() -> (STOMP.client)
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

      return client
    end


    # :call-seq:
    # NebRequest.with_timeout(secs) -> (nil)
    #
    # Run a routine with a timeout.
    #
    # Example:
    #  with_timeout(10) do |r|
    #    sleep 20
    #    r.signal
    #  end
    #
    # Use `r.signal` to signal when the process has finished. You need to
    # arrange your own method of working out whether the timeout fired or not.
    #
    # There is a Ruby standard library for this, Timeout. But there appears to
    # be some argument as to whether it is threadsafe; so, we roll our own. It
    # probably doesn't matter since both Redis and Stomp do use Timeout. But.
    #
    def self.with_timeout(secs)
      mutex    = Mutex.new
      resource = ConditionVariable.new

      Thread.new do
        mutex.synchronize do
          yield resource
        end
      end

      mutex.synchronize do
        resource.wait(mutex, secs)
      end

    end


    #
    # INSTANCE METHODS
    #

    # Send a request and return the response, without the cache.
    #
    # Raise NebulousTimeout or NebulousError as necessary.
    #
    # Note that this routine completely ignores Redis. It doesn't just not
    # check the cache; it also doesn't update it.
    #
    def send_no_cache
      #puts "Nebulous request- v:#{@verb} p:#{@params}" unless MODE == 'production'

      begin
        # If we've lost the connection then reconnect but *keep replyID*
        @client = NebRequest.stomp_connect unless @client.open?
        @replyID = get_replyID if @replyID.nil? 

        response = neb_qna
        return NebResponse.new(response) 

      ensure
        @client.close unless @client.nil?
      end

    end


    # As send_nocache, but without not checking the cache :)
    #
    # Raises NebulousTimeout, NebulousError as necessary.
    #
    # We use Redis for the cache. This is possibly like using a sledgehammer
    # to crack a nut, but it certainly makes things very simple.
    #
    def send
      return send_no_cache unless redis_on?

      #puts "Redis query- v:#{@verb} p:#{@params}" unless MODE == 'production'

      redis = nil

      begin
        redis = RedisHandler::connect 

        found = redis.get(@message)
        return NebResponse.new(found) unless found.nil?

        # No answer in Redis -- ask Nebulous
        nebMess = send_no_cache
        redis.set( @message, nebMess.to_cache, ex: @cTimeout ) 
        return nebMess

      ensure
        redis.quit unless redis.nil?
      end

    end


    # Connect to STOMP and do initial setup
    #
    def neb_connect
      @client ||= NebRequest.stomp_connect
      @replyID = calc_replyID
    end


    # Return true if Redis is turned on in the config
    #
    def redis_on?
      ! Param.get(:redisConnectHash).nil?
    end


    private
    #######

    
    # Send a message via STOMP and wait for a response
    #
    def neb_qna
      headers = { "content-type" => "application/json",
                  "neb-reply-to" => @responseQ,
                  "neb-reply-id" => @replyID }
                  
      # Ensure the response queue exists
      @client.publish( @responseQ, "boo" ) 

      # Send the request
      @client.publish(@requestQ, @message, headers)

      # wait for the response
      response = nil

      NebRequest.with_timeout(@mTimeout) do |x|

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
      return response

    end # of neb_qna


    # Return the neb-reply-id we're going to use for this connection
    # Return nil if we're not connected yet
    #
    def calc_replyID
      @client.nil? ? nil : @client.connection_frame().headers["session"]
    end


  end # of NebRequest


end

