# COding: UTF-8

require 'json'

require_relative 'stomp_handler'


module Nebulous


  ## 
  # A class to encapsulate a Nebulous message (which is built on top of a
  # STOMP message)
  #
  # Note that this class REPLACES the old NebResponse class from 0.1.0. There
  # are differences:
  #     * response.body -> message.stomp_body
  #     * response.headers -> message.stomp_headers
  #     * to_cache now returns a Hash, not a JSON string
  #
  class Message

    # Might be nil: parsed from incoming messages; set by StompHandler on send
    attr_accessor :reply_id

    # Might be nil: only caught on messages that came directly from STOMP
    attr_reader :stomp_headers, :stomp_body
    
    # The content type of the message
    attr_reader :content_type

    # The Nebulous Protocol
    # Note that if you happen to pass an array as @params, it's actually
    # writable, which is not ideal.
    attr_reader :verb, :params, :desc
    attr_reader :reply_to, :in_reply_to 


    class << self


      ##
      # Build a Message from its components.
      #
      # Note that we assume a content type of JSON. But if we are building a
      # message by hand in Ruby, this is only reasonable.
      #
      # You must pass a verb; you can pass nil for all the other values.
      #
      # * replyTo - the queue to reply to if this is a Request
      # * inReplyTo - the reply ID if this is a Response
      # * verb, params, desc - The Protocol; the message to pass
      #
      def from_parts(replyTo, inReplyTo, verb, params, desc)
        raise ArgumentError, "missing parts" unless verb

        Nebulous.logger.debug(__FILE__){ "New message from parts" }

        p = 
          case params
            when NilClass then nil
            when Array    then params.dup
            else params.to_s
          end

        self.new( replyTo:     replyTo.to_s,
                  inReplyTo:   inReplyTo.to_s,
                  verb:        verb.to_s,
                  params:      p,
                  desc:        desc.nil? ? nil : desc.to_s,
                  contentType: 'application/json' )

      end


      ##
      # Build a Message that replies to an existing Message
      #
      # * msg - the Nebulous::Message that you are replying to
      # * verb, params, desc - the new message Protocol 
      #
      def in_reply_to(msg, verb, params=nil, desc=nil, replyTo=nil)
        raise ArgumentError, 'bad message' unless msg.kind_of? Message

        Nebulous.logger.debug(__FILE__){ "New message reply" }

        p = 
          case params
            when NilClass then nil
            when Array    then params.dup
            else params.to_s
          end

        m = msg.clone
        self.new( replyTo:     replyTo.to_s,
                  verb:        verb.to_s,
                  params:      p,
                  desc:        desc.to_s,
                  inReplyTo:   m.reply_id,
                  contentType: m.content_type )

      end
      

      ##
      # Build a Message from a (presumably incoming) STOMP message
      #
      def from_stomp(stompMsg)
        raise ArgumentError, 'not a stomp message' \
          unless stompMsg.kind_of? Stomp::Message

        Nebulous.logger.debug(__FILE__){ "New message from STOMP" }

        s = Marshal.load( Marshal.dump(stompMsg) )
        obj = self.new( stompHeaders: s.headers,
                        stompBody:    s.body     )

      end


      ##
      # To build a Nebmessage from a record in the Redis cache
      #
      # See #to_cache for details of the hash that Redis should be storing
      # 
      def from_cache(json)
        raise ArgumentError, "That can't be JSON, it's not a string" \
          unless json.kind_of? String

        Nebulous.logger.debug(__FILE__){ "New message from cache" }

        # Note that the message body at this point, for a JSON message, is
        # actually encoded to JSON *twice* - the second time was when the cache
        # hash as a whole was encoded for store in Redis. the JSON gem copes
        # with this so long as the whole string is not double-encoded.
        hash = JSON.parse(json, :symbolize_names => true)
        raise ArgumentError, 'Empty cache entry' if hash == {}

        # So now if the content type is JSON then the body is still JSON now.
        # It's only the rest of the cache hash that is a now a hash. Confused?
        # Now join us for this weeks' episode...
        self.new( hash.clone )

      rescue JSON::ParserError => err  
        raise ArgumentError, "Bad JSON: #{err.message}"
      end

    end
    ##


    alias :parameters  :params
    alias :description :desc


    def to_s
      "<Message[#{@reply_id}] to:#{@reply_to} r-to:#{@in_reply_to} " \
        << "v:#{@verb}>"

    end


    ##
    # true if the content type appears to be JSON-y
    #
    def content_is_json?
      @content_type =~ /json$/i ? true : false
    end


    ##
    # Output a hash for serialization to the cache.
    #
    # Currently this looks like:
    #    { stompHeaders: @stomp_headers,
    #      stompBody:    @stomp_body,
    #      verb:         @verb,
    #      params:       @params,
    #      desc:         @desc,
    #      replyTo:      @reply_to,
    #      replyId:      @reply_id,
    #      inReplyTo:    @in_reply_to,
    #      contentType:  @content_type }
    #
    def to_cache
      { stompHeaders: @stomp_headers,
        stompBody:    @stomp_body,
        verb:         @verb,
        params:       @params.kind_of?(Enumerable) ? @params.dup : @params,
        desc:         @desc,
        replyTo:      @reply_to,
        replyId:      @reply_id,
        inReplyTo:    @in_reply_to,
        contentType:  @content_type }

    end


    ##
    # Return the hash of additional headers for the Stomp gem
    #
    def headers_for_stomp
      headers = { "content-type" => @content_type, 
                  "neb-reply-id" => @reply_id }

      headers["neb-reply-to"]    = @reply_to    if @reply_to
      headers["neb-in-reply-to"] = @in_reply_to if @in_reply_to

      headers
    end


    ##
    # Return a body object for the Stomp gem
    #
    def body_for_stomp
      hash = protocol_hash

      if content_is_json?
        hash.to_json
      else
        hash.map {|k,v| "#{k}: #{v}" }.join("\n") << "\n\n"
      end
    end


    ##
    # :call-seq:
    #   message.body_to_h -> (Hash || nil)
    #
    # If the body is in JSON, return a hash.
    # If body is nil, or is not JSON, then return nil; don't raise an exception
    #
    def body_to_h
      x = StompHandler.body_to_hash(stomp_headers, stomp_body, @content_type)
      x == {} ? nil : x
    end


    ##
    # Return the message body formatted for The Protocol, in JSON.
    #
    # Raise an exception if the message body doesn't follow the protocol.
    #
    # (We use this as the key for the Redis cache)
    #
    def protocol_json
      raise NebulousError, "no protocol in this message!" unless @verb
      protocol_hash.to_json
    end


    ##
    # Make a new 'success verb' message in response to this one
    #
    # returns [queue, message] so you can just pass it to
    # stomphandler.send_message.
    #
    def respond_success
      raise NebulousError, "Don''t know who to reply to" unless @reply_to

      Nebulous.logger.info(__FILE__) do
        "Responded to #{self} with 'success' verb"
      end

      [ @reply_to, Message.in_reply_to(self, 'success') ]
    end


    ##
    # Make a new 'error verb' message in response to this one
    #
    # err can be a string or an exception
    #
    # returns [queue, message] so you can just pass it to
    # stomphandler.send_message.
    #
    def respond_error(err,fields=[])
      raise NebulousError, "Don''t know who to reply to" unless @reply_to

      Nebulous.logger.info(__FILE__) do
        "Responded to #{self} with 'error': #{err}" 
      end

      reply = Message.in_reply_to(self, 'error', fields, err.to_s)

      [ @reply_to, reply ]
    end


    private


    ##
    # Create a record -- note that you can't call this directly on the class;
    # you have to call Message.from_parts, .from_stomp, .from_cache or
    # .in_reply_to.
    #
    def initialize(hash)
      @stomp_headers = hash[:stompHeaders]
      @stomp_body    = hash[:stompBody]

      @verb         = hash[:verb]
      @params       = hash[:params]
      @desc         = hash[:desc]
      @reply_to     = hash[:replyTo]
      @reply_id     = hash[:replyId]
      @in_reply_to  = hash[:inReplyTo]
      @content_type = hash[:contentType]

      fill_from_message
    end


    ##
    # Return The Protocol of the message as a hash.
    #
    def protocol_hash
      h = {verb: @verb}
      h[:parameters]  = @params unless @params.nil?
      h[:description] = @desc   unless @desc.nil?

      h
    end


    ##
    # Fill all the other attributes, if you can, from @stomp_headers and
    # @stomp_body.
    #
    def fill_from_message

      if @stomp_headers
        @content_type ||= @stomp_headers['content-type']
        @reply_id     ||= @stomp_headers['neb-reply-id']
        @reply_to     ||= @stomp_headers['neb-reply-to'] 
        @in_reply_to  ||= @stomp_headers['neb-in-reply-to']
      end

      # decode the body, which should either be a JSON string or a series of
      # text fields. And use the body to set Protocol attributes.
      if @stomp_body && !@stomp_body.empty?

        raise "body is not a string, something is very wrong here!" \
          unless @stomp_body.kind_of? String

        h = StompHandler.body_to_hash( @stomp_headers,
                                       @stomp_body,
                                       @content_type )

        @verb   ||= h["verb"]
        @params ||= h["parameters"]  || h["params"]
        @desc   ||= h["description"] || h["desc"]

        # Assume that if verb is missing, the other two are just part of a
        # response which has nothing to do with the protocol
        @params = @desc = nil unless @verb
      end

      self
    end

  end
  ##


end

