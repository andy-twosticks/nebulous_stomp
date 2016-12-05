require 'json'
require 'forwardable'

require_relative 'stomp_handler'
require_relative 'msg/header'
require_relative 'msg/body'


module NebulousStomp


  ## 
  # A class to encapsulate a Nebulous message (which is built on top of a
  # STOMP message)
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
      # Build a Message that replies to an existing Message
      #
      # * msg - the Nebulous::Message that you are replying to
      # * args - hash as per Message.new
      #
      # See also #respond, #respond_with_protocol, etc, etc.
      #
      def in_reply_to(msg, args)
        raise ArgumentError, 'bad message'             unless msg.kind_of? Message
        raise ArgumentError, 'bad hash'                unless args.kind_of? Hash
        raise ArgumentError, 'message has no reply ID' unless msg.reply_id

        NebulousStomp.logger.debug(__FILE__){ "New message in reply to #{msg}" }

        hash = { inReplyTo:   msg.reply_id,
                 contentType: msg.content_type }

        self.new(args.merge hash)
      end
      
      ##
      # Build a Message from a (presumably incoming) STOMP message
      #
      def from_stomp(stompMsg)
        raise ArgumentError, 'not a stomp message' unless stompMsg.kind_of? Stomp::Message
        NebulousStomp.logger.debug(__FILE__){ "New message from STOMP" }

        s = Marshal.load( Marshal.dump(stompMsg) )
        self.new(stompHeaders: s.headers, stompBody: s.body)
      end

      ##
      # To build a Nebmessage from a record in the Redis cache
      #
      # See #to_cache for details of the hash that Redis should be storing
      # 
      def from_cache(json)
        raise ArgumentError, "That can't be JSON, it's not a string" unless json.kind_of? String
        NebulousStomp.logger.debug(__FILE__){ "New message from cache" }

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
    def to_cache
      @header.to_cache.merge @body.to_cache
    end

    ##
    # Repond with a message using The Protocol
    #
    def respond_with_protocol(verb, params=[], desc="")
      raise NebulousError, "Don't know which queue to reply to" unless reply_to
      
      hash = {verb: verb, params: params, desc: desc}
      [ reply_to, Message.in_reply_to(self, hash) ]
    end

    ##
    # Repond with a message (presumably a custom one that's non-Protocol)
    #
    def respond(body)
      raise NebulousError, "Don't know which queue to reply to" unless reply_to
      [ reply_to, Message.in_reply_to(self, body: body) ]
    end

    ##
    # Make a new 'success verb' message in response to this one
    #
    # returns [queue, message] so you can just pass it to
    # stomphandler.send_message.
    #
    def respond_with_success
      raise NebulousError, "Don't know which queue to reply to" unless reply_to
      respond_with_protocol('success')
    end

    alias :respond_success :respond_with_success # old name

    ##
    # Make a new 'error verb' message in response to this one
    #
    # err can be a string or an exception
    #
    # returns [queue, message] so you can just pass it to
    # stomphandler.send_message.
    #
    def respond_with_error(err, fields=[])
      raise NebulousError, "Don't know which queue to reply to" unless reply_to
      respond_with_protocol('error', Array(fields).flatten.map(&:to_s), err.to_s)
    end

    alias :respond_error :respond_with_error # old name

  end # Message


end

