require 'json'
require 'forwardable'

require_relative 'stomp_handler'
require_relative 'msg/header'
require_relative 'msg/body'


module NebulousStomp


  ## 
  # A class to encapsulate a Nebulous message (which is built on top of a STOMP message)
  #
  # This class is entirely read-only, except for reply_id, which is set by Request when the
  # message is sent.
  #
  class Message
    extend Forwardable

    def_delegators :@header, :stomp_headers, :reply_to, :in_reply_to, :reply_id, :content_type,
                             :reply_id=, :content_is_json?, :headers_for_stomp

    def_delegators :@body, :stomp_body, :body, :verb, :params, :desc,
                           :body_to_h, :protocol_json, :body_for_stomp

    alias :parameters  :params
    alias :description :desc


    class << self

      ##
      # :call-seq: 
      # Message.in_reply_to(message, hash) -> Message
      #
      # Build a Message that replies to an existing Message
      #
      # * msg - the Nebulous::Message that you are replying to
      # * args - hash as per Message.new
      #
      # See also #respond, #respond_with_protocol, etc, etc.
      #
      # Note that this method absolutely enforces the protocol with regard to the content type and
      # (of course) the id of the message it is replying to; for example, even if you pass a
      # different content type it will take the content type of the msg in preference. If you want
      # something weirder, you will have to use Message.new.
      #
      def in_reply_to(msg, args)
        fail ArgumentError, 'bad message'             unless msg.kind_of? Message
        fail ArgumentError, 'bad hash'                unless args.kind_of? Hash
        fail ArgumentError, 'message has no reply ID' unless msg.reply_id

        NebulousStomp.logger.debug(__FILE__){ "New message in reply to #{msg}" }

        hash = { inReplyTo:   msg.reply_id,
                 contentType: msg.content_type }

        self.new(args.merge hash)
      end
      
      ##
      # :call-seq: 
      # Message.from_stomp(stompmessage) -> Message
      #
      # Build a Message from a (presumably incoming) STOMP message; stompmessage must be a
      # Stomp::Message.
      #
      def from_stomp(stompMsg)
        fail ArgumentError, 'not a stomp message' unless stompMsg.kind_of? Stomp::Message
        NebulousStomp.logger.debug(__FILE__){ "New message from STOMP" }

        s = Marshal.load( Marshal.dump(stompMsg) )
        self.new(stompHeaders: s.headers, stompBody: s.body)
      end

      ##
      # :call-seq: 
      # Message.from_cache(hash) -> Message
      #
      # To build a Nebmessage from a record in the Redis cache
      #
      # See #to_cache for details of the hash that Redis should be storing
      # 
      def from_cache(json)
        fail ArgumentError, "That can't be JSON, it's not a string" unless json.kind_of? String
        NebulousStomp.logger.debug(__FILE__){ "New message from cache" }

        # Note that the message body at this point, for a JSON message, is actually encoded to JSON
        # *twice* - the second time was when the cache hash as a whole was encoded for store in
        # Redis. the JSON gem copes with this so long as the whole string is not double-encoded.
        hash = JSON.parse(json, :symbolize_names => true)
        fail ArgumentError, 'Empty cache entry' if hash == {}

        # So now if the content type is JSON then the body is still JSON now. It's only the rest of
        # the cache hash that is a now a hash. Confused? Now join us for this weeks' episode...
        self.new( hash.clone )

      rescue JSON::ParserError => err  
        fail ArgumentError, "Bad JSON: #{err.message}"
      end

    end # class << self


    ##
    # Create a new message,
    #
    # There are three ways that a message could get created:
    #
    #     1. The user could create one directly.
    #
    #     2. A message could be created from an incoming STOMP message, in which case we should
    #        call Message.from_stomp to create it.
    #
    #     3. A message could be created because we have retreived it from the Redis cache, in which
    #        case we should call Message.from_cache to create it (and, note, it will originally 
    #        have been created in one of the other two ways...)
    #
    # The full list of useful hash keys is (as per Message.from_cache, #to_cache):
    #
    #     * :body                 -- the message body
    #     * :contentType          -- Stomp content type string
    #     * :description / :desc  -- part of The Protocol
    #     * :inReplyTo            -- message ID that message is a response to
    #     * :parameters / :params -- part of The Protocol
    #     * :replyId              -- the 'unique' ID of this Nebulous message
    #     * :replyTo              -- for a request, the queue to be used for the response
    #     * :stompBody            -- for a message from Stomp, the raw Stomp message body
    #     * :stompHeaders         -- for a message from Stomp, the raw Stomp Headers string
    #     * :verb                 -- part of The Protocol
    #
    def initialize(hash)
      @header = Msg::Header.new(hash)
      @body = Msg::Body.new(content_is_json?, hash)
    end

    def to_s
      "<Message[#{reply_id}] to:#{reply_to} r-to:#{in_reply_to} v:#{verb}>"
    end

    ##
    # Output a hash for serialization to the Redis cache.
    #
    # Currently this looks like:
    #    { stompHeaders: @stomp_headers,
    #      stompBody:    @stomp_body,
    #      body:         @body
    #      verb:         @verb,
    #      params:       @params,
    #      desc:         @desc,
    #      replyTo:      @reply_to,
    #      replyId:      @reply_id,
    #      inReplyTo:    @in_reply_to,
    #      contentType:  @content_type }
    #
    # Note that if :stompBody is set then :body will be nil. This is to attempt to reduce
    # duplication of what might be a rather large string.
    #
    def to_h
      @header.to_h.merge @body.to_h
    end

    alias :to_cache :to_h  # old name

    ##
    # :call-seq: 
    # message.respond_with_protocol(verb, params=[], desc="") -> queue, Message
    #
    # Repond with a message using The Protocol.
    #
    def respond_with_protocol(verb, params=[], desc="")
      fail NebulousError, "Don't know which queue to reply to" unless reply_to
      
      hash = {verb: verb, params: params, desc: desc}
      [ reply_to, Message.in_reply_to(self, hash) ]
    end

    ##
    # :call-seq: 
    # message.respond_with_protocol(body) -> queue, Message
    #
    # Repond with a message body (presumably a custom one that's non-Protocol).
    # 
    def respond(body)
      fail NebulousError, "Don't know which queue to reply to" unless reply_to

      # Easy to do by mistake, pain in the arse to work out what's going on if you do
      fail ArgumentError, "Respond takes a body, not a message" if body.is_a? Message 

      mess = Message.in_reply_to(self, body: body)
      [ reply_to, mess ]
    end

    ##
    # :call-seq: 
    # message.respond_with_success -> queue, Message
    #
    # Make a new 'success verb' message in response to this one.
    #
    def respond_with_success
      fail NebulousError, "Don't know which queue to reply to" unless reply_to
      respond_with_protocol('success')
    end

    alias :respond_success :respond_with_success # old name

    ##
    # :call-seq: 
    # message.respond_with_error(error, fields=[]) -> queue, Message
    #
    # Make a new 'error verb' message in response to this one.
    #
    # Error can be a string or an exception. Fields is an arbitrary array of values, designed as a
    # list of the parameter keys with problems; but of course you can use it for whatever you like.
    #
    def respond_with_error(err, fields=[])
      fail NebulousError, "Don't know which queue to reply to" unless reply_to
      respond_with_protocol('error', Array(fields).flatten.map(&:to_s), err.to_s)
    end

    alias :respond_error :respond_with_error # old name

  end # Message


end

