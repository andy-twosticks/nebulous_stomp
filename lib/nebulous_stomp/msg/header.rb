require 'json'

require_relative '../stomp_handler'


module NebulousStomp
  module Msg


    ## 
    # A class to encapsulate a Nebulous message header - a helper class for Message
    #
    class Header

      # Might be nil: parsed from incoming messages; set by StompHandler on send
      attr_accessor :reply_id

      # Might be nil: only caught on messages that came directly from STOMP
      attr_reader :stomp_headers
      
      # The content type of the message
      attr_reader :content_type

      # From The Nebulous Protocol
      attr_reader :reply_to, :in_reply_to 

      ##
      #
      def initialize(hash)
        @stomp_headers = hash[:stompHeaders]
        @reply_to      = hash[:replyTo]
        @reply_id      = hash[:replyId]
        @in_reply_to   = hash[:inReplyTo]
        @content_type  = hash[:contentType]
        
        # If we have no stomp headers then we (probably correctly) assume that this is a user
        # created message, and default the content type to JSON.
        @content_type = 'application/json' if @stomp_headers.nil? && @content_type.nil?

        fill_from_stomp
      end

      ##
      # true if the content type appears to be JSON-y
      #
      def content_is_json?
        @content_type =~ /json$/i ? true : false
      end

      ##
      # Output a the header part of the hash for serialization to the cache.
      #
      def to_h
        { stompHeaders: @stomp_headers,
          replyTo:      @reply_to,
          replyId:      @reply_id,
          inReplyTo:    @in_reply_to,
          contentType:  @content_type }

      end

      ##
      # Return the hash of additional headers for the Stomp gem
      #
      def headers_for_stomp
        { "content-type"    => @content_type, 
          "neb-reply-id"    => @reply_id,
          "neb-reply-to"    => @reply_to,
          "neb-in-reply-to" => @in_reply_to }
        
      end

      private

      ##
      # Fill all the other attributes, if you can, from @stomp_headers
      #
      def fill_from_stomp
        return unless @stomp_headers

        type = @stomp_headers["content-type"] || @stomp_headers[:'content-type'] \
            || @stomp_headers["content_type"] || @stomp_headers[:content_type]   \
            || @stomp_headers["contentType"]  || @stomp_headers[:contentType]
        
        @content_type ||= type
        @reply_id     ||= @stomp_headers['neb-reply-id']
        @reply_to     ||= @stomp_headers['neb-reply-to'] 
        @in_reply_to  ||= @stomp_headers['neb-in-reply-to']

        self
      end

    end # of Header


  end
end

