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
        @params     = hash[:parameters] || hash[:params] 
        @desc       = hash[:description] || hash[:desc]

        fill_from_stomp

        @stomp_body = fix_bad_encoding(@stomp_body)
        @body       = fix_bad_encoding(@body)
        @verb       = fix_bad_encoding(@verb)
        @params     = fix_bad_encoding(@params)
        @desc       = fix_bad_encoding(@desc)
      end

      ##
      # Output a the body part of the hash for serialization to the cache.
      #
      # Since the body could be quite large we only set :body if there is no @stomp_body. We
      # recreate the one from the other anyway.
      #
      def to_h
        { stompBody: @stomp_body,
          body:      @stomp_body ? nil : @body,
          verb:      @verb,
          params:    @params.kind_of?(Enumerable) ? @params.dup : @params,
          desc:      @desc }
        
      end

      ##
      # Return a body object for the Stomp gem
      #
      def body_for_stomp

        case 
          when @is_json
            @body.to_json
          when @body.is_a?(Hash)
            @body.map{|k,v| "#{k}: #{v}" }.join("\n") << "\n\n"
          else
            @body.to_s
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
        fail NebulousError, "no protocol in this message!" unless @verb
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
      # Fill all the other attributes, if we can.
      #
      # Note that we confusingly store @verb, @params, & @desc (The Protocol, which if present is
      # the message body); @body (the message body); and @stomp_body (the original body from the
      # stomp message if we were created from one). Any of these could be passed in the initialize
      # hash.
      #
      # The rule is that we always prioritize them in that order. If we are passed a @verb, then
      # the Protocol fields go into @body; otherwise if set we take @body as it stands; otherwise
      # we try and decode @stomp_body and set that in @body.
      #
      # NB: We never overwrite @stomp_body. If not passed to us, it stays nil. It's only stored in
      # case we can't decode it, as a fallback.
      #
      def fill_from_stomp

        if @verb
          @body = protocol_hash
        elsif @body.nil? || @body.respond_to?(:empty?) && @body.empty?
          sb = parse_stomp_body 
          @body = sb if sb
        end

        parse_body

        # Assume that if verb is missing, the other two are just part of a
        # response which has nothing to do with the protocol
        @params = @desc = nil unless @verb

        self
      end

      def parse_stomp_body
        case
          when @stomp_body.nil? then nil
          when @is_json         then stomp_body_from_json
          else 
            stomp_body_from_text
            
        end
      end

      def stomp_body_from_json
        JSON.parse(@stomp_body)
      rescue JSON::ParserError, TypeError
        # If we can't parse it, fine, take it as a text blob
        @stomp_body.to_s
      end

      def stomp_body_from_text
        lines = @stomp_body.to_s.split("\n").reject{|s| s =~ /^\s*$/ }
        hash  = {}

        lines.each do |line|
          k,v = line.split(':', 2).each{|x| x.strip! }
          hash[k] = v if line.include?(':')
        end

        # If there are any lines we could not parse, forget the whole thing and return a text blob
        (lines.size > hash.keys.size) ? @stomp_body.to_s : hash
      end

      def parse_body
        if @body.is_a?(Hash)
          @verb   ||= @body["verb"]
          @params ||= @body["parameters"]  || @body["params"]
          @desc   ||= @body["description"] || @body["desc"]
        end
      end

      ##
      # Deal with encoding problems.  Try ISO8859-1 first.  (Sorry for the Western bias, but this
      # solves a lot of use-cases for us.)
      #
      def fix_bad_encoding(string)
        return string unless string.is_a? String

        unless string.valid_encoding?
          s = string.encode("UTF-8", "ISO8859-1") 
          string = s if s.valid_encoding?
        end

        string.encode!(invalid: :replace, undef: :replace) unless string.valid_encoding?
        string
      end

    end # Message::Body


  end
end
