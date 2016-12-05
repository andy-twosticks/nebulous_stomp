require 'json'

require_relative '../stomp_handler'


module NebulousStomp
  module Msg


    ## 
    # A class to encapsulate a Nebulous message body - helper class for Message
    #
    class Body

      # Might be nil: only caught on messages that came directly from STOMP
      attr_reader :stomp_body

      # The Nebulous Protocol
      # Note that if you happen to pass an array as @params, it's actually
      # writable, which is not ideal.
      attr_reader :verb, :params, :desc

      ##
      # is_json should be a boolean, true if the body is JSON-encoded.
      # If it is false then we assume that we are coded like STOMP headers, in lines of text.
      #
      def initialize(is_json, hash)
        @is_json    = !!is_json
        @stomp_body = hash[:stompBody]
        @verb       = hash[:verb]
        @params     = hash[:params]
        @desc       = hash[:desc]

        fill_from_stomp
      end

      ##
      # Output a the body part of the hash for serialization to the cache.
      #
      def to_cache
        { stompBody: @stomp_body,
          verb:      @verb,
          params:    @params.kind_of?(Enumerable) ? @params.dup : @params,
          desc:      @desc }

      end

      ##
      # Return a body object for the Stomp gem
      #
      def body_for_stomp
        hash = protocol_hash

        if @is_json
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
        hash = body_to_hash
        hash == {} ? nil : hash
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

      private

      ##
      # Return The Protocol of the message as a hash.
      #
      def protocol_hash
        { verb:        @verb,
          parameters:  @params,
          description: @desc   }.delete_if{|_,v| v.nil? }
        
      end

      ##
      # Fill all the other attributes, if you can, from @stomp_body.
      #
      # BAMF - we need the content type from the header!
      #
      def fill_from_stomp
        return unless @stomp_body && !@stomp_body.empty?
        raise "body is not a string, something is very wrong here!" \
          unless @stomp_body.kind_of? String

        # decode the body, which should either be a JSON string or a series of
        # text fields. And use the body to set Protocol attributes.
        h = body_to_hash

        @verb   ||= h["verb"]
        @params ||= h["parameters"]  || h["params"]
        @desc   ||= h["description"] || h["desc"]

        # Assume that if verb is missing, the other two are just part of a
        # response which has nothing to do with the protocol
        @params = @desc = nil unless @verb

        self
      end

      def body_to_hash
        @is_json ? body_to_hash_json : body_to_hash_text
      end

      def body_to_hash_json
        JSON.parse(@stomp_body)
      rescue JSON::ParserError, TypeError
        {}
      end

      # We assume that text looks like STOMP headers, or nothing
      def body_to_hash_text
        hash = {}
        @stomp_body.to_s.split("\n").each do |line|
          k,v = line.split(':', 2).each{|x| x.strip! }
          hash[k] = v
        end
        hash
      end

    end # Message::Body


  end
end
