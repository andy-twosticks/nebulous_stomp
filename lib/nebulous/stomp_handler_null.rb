# COding: UTF-8

require 'stomp'
require 'json'
require 'time'

require_relative 'stomp_handler'
require_relative 'message'


module Nebulous


  ##
  # Behaves just like StompHandler, except, does nothing and expects no stomp
  # connection
  #
  class StompHandlerNull < StompHandler


    def initialize(hash=nil)
      super(hash)

      @fakeMess = 
        Nebulous::Message.from_cache( { stompHeaders: {},
                                        stompBody:    '',
                                        verb:         '',
                                        params:       '',
                                        desc:         '',
                                        replyTo:      nil,
                                        replyId:      nil,
                                        inReplyTo:    nil,
                                        contentType:  nil }.to_json )


    end


    def insert_fake(verb, params, desc)
      @fakeMess = Message.from_parts( nil, nil, verb, params, desc )
    end


    def stomp_connect
      Nebulous.logger.info(__FILE__) {"Connecting to STOMP (Null)"} 

      @client = true
      self
    end


    def stomp_disconnect
      Nebulous.logger.info(__FILE__) {"STOMP Disconnect (Null)"}
      @client = nil
      self
    end

    
    def connected?; true; end


    def listen(queue, timeout = nil)
      Nebulous.logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}
      yield @fakeMess
    end

    alias :listen_with_timeout :listen


    def send_message(queue, nebMess)
      nebMess
    end


    def respond_success(nebMess)
      Nebulous.logger.info(__FILE__) do 
        "Responded to #{nebMess} with 'success' verb (to Null)"
      end
    end


    def respond_error(nebMess,err,fields=[])
      Nebulous.logger.info(__FILE__) do
        "Responded to #{nebMess} with 'error' verb: #{err} (to Null)"
      end
    end


    def calc_reply_id; 'ABCD123456789'; end


  end


end

