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


    alias :headers :stomp_headers
    alias :body    :stomp_body


    ##
    # :call-seq:
    #   response.body_to_h -> (Hash || nil)
    #
    # If the body is in JSON, return a hash. 
    # If body is nil, or is not JSON, then return nil; don't raise an exception
    #
    def body_to_h
      x = StompHandler.body_to_hash(headers, body, @content_type) 
      x == {} ? nil : x
    end


  end # of NebResponse

end

