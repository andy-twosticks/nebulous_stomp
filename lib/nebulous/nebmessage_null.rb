# COding: UTF-8

require 'json'

require_relative 'stomp_handler_null'
require_relative 'message'


module Nebulous


  class MessageNull < Message

    attr_accessor :reply_id

    attr_reader :stomp_message, :content_type
    attr_reader :verb, :params, :desc
    attr_reader :reply_to, :in_reply_to 
    attr_reader :status


    class << self


      # Build a Message from a (presumably incoming) STOMP message
      def from_stomp(stompMsg)
        obj = self.new( stompMessage: stompMsg )
        obj.fill_from_message
      end


      # Build a Message from its components
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
      "<NebMessageNull[#{@reply_id}] to:#{@reply_to} r-to:#{@in_reply_to} " \
        << "v:#{@verb} p:#{@params}>"

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


    def fill_from_message
      @content_type = @stomp_message.headers['content-type']
      @reply_id     = @stomp_message.headers['neb-reply-id']
      @reply_to     = @stomp_message.headers['neb-reply-to'] 
      @in_reply_to  = @stomp_message.headers['neb-in-reply-to']

      h = StompHandlerNull.body_to_hash(@stomp_message)

      @verb   = h["verb"]
      @params = h["parameters"] || h["params"]
      @desc   = h["description"] || h["desc"]

      # Assume that if verb is missing, the other two are just part of a
      # response which has nothing to do with the protocol
      @params = @desc = nil unless @verb

      self
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
      @status        = hash[:status]
    end


  end


end

