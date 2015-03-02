# coding: UTF-8

require 'stomp'
require 'json'


module Nebulous


  # Class to carry the response message back to the caller 
  # (and make sense of it)
  #
  class NebResponse

    attr_reader :headers   # STOMP message headers
    attr_reader :body      # convenient access to message body
    attr_reader :verb, :parameters, :description # The Protocol


    # NebResponse can be initialised by passing it either:
    # * a STOMP message -- returned from a Nebulous request
    # * a JSON string -- from Redis, originally created by to_cache()
    #
    # If you pass it anything else, it will raise a NebulousError.
    #
    def initialize(thingy)
      case thingy
        when Stomp::Message then initialize_from_stomp(thingy)
        when String         then initialize_from_string(thingy)
        else raise NebulousError,
                   "Unknown class #{thingy.class} passed to NebResponse.new"

      end
    end


    # Initialise the object from a STOMP message
    #
    def initialize_from_stomp(stompMessage)
      @headers = stompMessage.headers
      @body    = stompMessage.body

      @verb, @parameters, @description = nil, nil, nil

      if stompMessage.headers["content-type"] =~ /json/i
        h = body_to_h()

      else
        # We assume that text looks like STOMP headers, or nothing

        h = {}
        stompMessage.body.split("\n").each do |line|
          k,v = line.split(':', 2).each{|x| x.strip! }
          h[k] = v
        end

      end

      @verb        = h["verb"]
      @parameters  = h["parameters"] || h["params"]
      @description = h["description"] || h["desc"]
    end


    # Initialise the object from a JSON string 
    #
    def initialize_from_string(string)
      begin
        h = JSON::parse(string)
      rescue JSON::ParserError => e
        raise NebulousError, e.message
      end

      @headers     = h["headers"]
      @body        = h["body"]
      @verb        = h["verb"]
      @parameters  = h["parameters"]
      @description = h["description"]
    end


    # If the body is in JSON, return a hash. Raises a JSON::ParseError if it
    # isn't.
    #
    def body_to_h
      begin
        return JSON::parse(@body)
      rescue JSON::ParserError
        return nil
      end
    end


    # Return something that can be serialised in Redis
    #
    def to_cache
      { headers:     @headers,
        body:        @body,
        verb:        @verb,
        parameters:  @parameters,
        description: @description }.to_json
    end


  end # of NebResponse

end

