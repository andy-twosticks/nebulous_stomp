# COding: UTF-8

require 'json'

require_relative 'stomp_handler_null'
require_relative 'message'


module Nebulous


  ##
  # A does-nothing version of Nebulous::Message, for testing
  #
  class MessageNull < Message

    attr_accessor :reply_id

    attr_reader :stomp_message, :content_type
    attr_reader :verb, :params, :desc
    attr_reader :reply_to, :in_reply_to 
    attr_reader :status


    def to_s
      "<NebMessageNull[#{@reply_id}] to:#{@reply_to} r-to:#{@in_reply_to} " \
        << "v:#{@verb} p:#{@params}>"

    end


    def fill_from_message
      super(StompHandlerNull)
    end


  end
  ##


end

