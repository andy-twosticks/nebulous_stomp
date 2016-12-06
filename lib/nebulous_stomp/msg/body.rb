require 'json'

require_relative '../stomp_handler'


module NebulousStomp
  module Msg


    ## 
    # A class to encapsulate a Nebulous message body - helper class for Message
    #
    class Body

      # Might be nil: only caught on messages that came directly from STOMP.
      attr_reader :stomp_body

      # The Nebulous Protocol
      # Note that if you happen to pass an array as @params, it's actually
      # writable, which is not ideal.
      attr_reader :verb, :params, :desc

      # Will be a hash for messages that follow The Protocol; anything at all otherwise.
      attr_reader :body

      ##
      # is_json should be a boolean, true if the body is JSON-encoded.
      # If it is false then we assume that we are coded like STOMP headers, in lines of text.
      #
      def initialize(is_json, hash)
        @is_json    = !!is_json
        @stomp_body = hash[:stompBody]
        @body       = hash[:body]
        @verb       = hash[:verb]
        @params     = hash[:params]
        @desc       = hash[:desc]

        fill_from_stomp
      end

      ##
      # Output a the body part of the hash for serialization to the cache.
      #
      # Since the body could be quite large we only set :body if there is no @stomp_body. We
      # recreate the one from the other anyway.
      #
      def to_h
        { stompBody: @stomp_body,
          body:      @stomp_body ? nil : body,
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
      def fill_from_stomp
        @body = parse_stomp_body

        if @body && !@body.empty?
          @verb   ||= @body["verb"]
          @params ||= @body["parameters"]  || @body["params"]
          @desc   ||= @body["description"] || @body["desc"]

          # Assume that if verb is missing, the other two are just part of a
          # response which has nothing to do with the protocol
          @params = @desc = nil unless @verb
        end

        self
      end

      def parse_stomp_body
        h = (@is_json ? stomp_body_from_json : stomp_body_from_text)

        if h.nil? || h == {}
          @stomp_body || @body 
        else
          h
        end
      end

      def stomp_body_from_json
        JSON.parse(@stomp_body)
      rescue JSON::ParserError, TypeError
        {}
      end

      # We assume that text looks like STOMP headers, or nothing
      def stomp_body_from_text

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
