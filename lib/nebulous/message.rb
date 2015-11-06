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
    attr_reader :stomp_message
    
    # The content type of the message
    attr_reader :content_type

    attr_reader :verb, :params, :desc
    attr_reader :reply_to, :in_reply_to 


    class << self


      # Build a NebMessage from a (presumably incoming) STOMP message
      def from_stomp(stompMsg)
        obj = self.new( stompMessage: stompMsg )
        obj.fill_from_message
      end


      # Build a NebMessage from its components
      def from_parts(replyTo, inReplyTo, verb, params, desc)

        self.new( replyTo:     replyTo,
                  inReplyTo:   inReplyTo,
                  verb:        verb,
                  params:      params,
                  desc:        desc,
                  contentType: 'application/json' )

      end


      # Build a message that replies to an existing NebMessage
      def in_reply_to(nebMsg, verb, params=nil, desc=nil, replyTo=nil)

        self.new( replyTo:     replyTo,
                  verb:        verb,
                  params:      params,
                  desc:        desc,
                  inReplyTo:   nebMsg.reply_id,
                  contentType: nebMsg.content_type )

      end


      # To build a Nebmessage from a record in the Redis cache
      def from_cache(json)
        hash = JSON.parse(json).inject({}) {|m,(k,v)| m[k.to_sym] = v; m }
        self.new( hash )
      rescue
        raise "Bad JSON, bamf"
      end

    end
    ##


    def to_s
      "<NebMessage[#{@reply_id}] to:#{@reply_to} r-to:#{@in_reply_to} " \
        << "v:#{@verb} p:#{@params}>"

    end


    def parameters; @params; end


    def content_is_json?
      @content_type =~ /json$/i
    end


    def to_cache
      { stomp_message: @stomp_message,
        verb:          @verb,
        params:        @params,
        desc:          @desc,
        reply_to:      @reply_to,
        reply_id:      @reply_id,
        in_reply_to:   @in_reply_to }

    end


    def fill_from_message(handler=StompHandler)
      @content_type = @stomp_message.headers['content-type']
      @reply_id     = @stomp_message.headers['neb-reply-id']
      @reply_to     = @stomp_message.headers['neb-reply-to'] 
      @in_reply_to  = @stomp_message.headers['neb-in-reply-to']

      h = handler.body_to_hash(@stomp_message)

      @verb   = h["verb"]
      @params = h["parameters"] || h["params"]
      @desc   = h["description"] || h["desc"]

      # Assume that if verb is missing, the other two are just part of a
      # response which has nothing to do with the protocol
      @params = @desc = nil unless @verb

      self
    end


    ##
    # Return the header Hash for the STOMP gem
    #
    def stomp_header
      headers = {"content-type" => @content_type, "neb-reply-id" => @reply_id}

      headers["neb-reply-to"]    = @reply_to    if @reply_to
      headers["neb-in-reply-to"] = @in_reply_to if @in_reply_to
    end


    ##
    # Return The Protocol of the message as a hash
    #
    def stomp_body
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
      raise "no protocol in this message!" unless @verb
      protocol_hash.to_json
    end


    private


    def initialize(hash)
      @stomp_message = hash[:stompMessage]
      @verb          = hash[:verb]
      @params        = hash[:params]
      @desc          = hash[:desc]
      @reply_to      = hash[:replyTo]
      @reply_id      = hash[:replyId]
      @in_reply_to   = hash[:inReplyTo ]
    end


    def protocol_hash
      h = {verb: @verb}
      h[:parameters]  = @params unless @params.nil?
      h[:description] = @desc   unless @desc.nil?
    end


  end
  ##


end

