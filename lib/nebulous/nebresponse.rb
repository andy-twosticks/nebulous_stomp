# coding: UTF-8

require 'stomp'
require 'json'

require_relative 'message'


module Nebulous


  ##
  # Class to carry the response message back to the caller (and make sense of
  # it)
  #
  # All of this functionality now lives in Nebulous::Message, but for backward
  # compatibility reasons the class is still a Thing.
  #
  class NebResponse < Message


    ##
    # Return the message headers from the stomp message
    #
    def headers
      @stomp_message ? @stomp_headers : nil
    end


    ##
    # Return the message body from the stomp message
    #
    def body
      @stomp_message ? @stomp_body : nil
    end


    ##
    # :call-seq:
    #   response.body_to_h -> (Hash || nil)
    #
    # If the body is in JSON, return a hash. 
    # If body is nil, or is not JSON, then return nil; don't raise an exception
    #
    def body_to_h
      x = StompHandler.body_to_h(headers, body) 
      x == {} ? nil : x
    end


  end # of NebResponse

end

