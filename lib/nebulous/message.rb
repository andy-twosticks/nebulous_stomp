# COding: UTF-8

require 'json'

require_relative 'stomp_handler'


module Nebulous


  ## 
  # A class to encapsulate a Nebulous message (which is built on top of a
  # STOMP message)
  #
  class Message

    # Might be nil: parsed from incoming messages; set by StompHandler on send
    attr_accessor :reply_id

    # Might be nil: only caught on messages that came directly from STOMP
    attr_reader :stomp_headers, :stomp_body
    
    # The content type of the message
    attr_reader :content_type

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
      def from_parts(replyTo, inReplyTo, verb, params, desc)
        raise ArgumentError, "missing parts" unless verb

        Nebulous.logger.debug(__FILE__){ "New message from parts" }

        self.new( replyTo:     replyTo,
                  inReplyTo:   inReplyTo,
                  verb:        verb,
                  params:      params,
                  desc:        desc,
                  contentType: 'application/json' )

      end


      ##
      # Build a Message that replies to an existing Message
      #
      def in_reply_to(msg, verb, params=nil, desc=nil, replyTo=nil)
        raise ArgumentError, 'bad message' unless msg.kind_of? Message

        Nebulous.logger.debug(__FILE__){ "New message reply" }

        self.new( replyTo:     replyTo,
                  verb:        verb,
                  params:      params,
                  desc:        desc,
                  inReplyTo:   msg.reply_id,
                  contentType: msg.content_type )

      end
      

      ##
      # Build a Message from a (presumably incoming) STOMP message
      #
      def from_stomp(stompMsg)
        raise ArgumentError, 'not a stomp message' \
          unless stompMsg.kind_of? Stomp::Message

        Nebulous.logger.debug(__FILE__){ "New message from STOMP" }

        obj = self.new( stompHeaders: stompMsg.headers,
                        stompBody:    stompMsg.body )

        #obj.fill_from_message bamf
      end



      ##
      # To build a Nebmessage from a record in the Redis cache
      # 
      def from_cache(json)
        raise ArgumentError, "That can''t be JSON, it''s not a string" \
          unless json.kind_of? String

        Nebulous.logger.debug(__FILE__){ "New message from cache" }

        hash = JSON.parse(json, :symbolize_names => true)
        raise ArgumentError, 'Empty cache entry' if hash == {}

        self.new( hash )

      rescue => err
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
    def to_cache
      { stompHeaders: @stomp_headers,
        stompBody:    @stomp_body,
        verb:         @verb,
        params:       @params,
        desc:         @desc,
        replyTo:      @reply_to,
        replyId:      @reply_id,
        inReplyTo:    @in_reply_to,
        contentType:  @content_type }

    end


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

      fill_from_message if @stomp_headers || @stomp_body

      @verb          ||= hash[:verb]
      @params        ||= hash[:params]
      @desc          ||= hash[:desc]
      @reply_to      ||= hash[:replyTo]
      @reply_id      ||= hash[:replyId]
      @in_reply_to   ||= hash[:inReplyTo]
      @content_type  ||= hash[:contentType]
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
      @content_type = @stomp_headers['content-type']
      @reply_id     = @stomp_headers['neb-reply-id']
      @reply_to     = @stomp_headers['neb-reply-to'] 
      @in_reply_to  = @stomp_headers['neb-in-reply-to']

      h = StompHandler.body_to_hash(@stomp_headers, @stomp_body)

      @verb   = h["verb"]
      @params = h["parameters"] || h["params"]
      @desc   = h["description"] || h["desc"]

      # Assume that if verb is missing, the other two are just part of a
      # response which has nothing to do with the protocol
      @params = @desc = nil unless @verb

      self
    end

  end
  ##


end

