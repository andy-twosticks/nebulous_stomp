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

    attr_reader :fake_mess


    def initialize(hash={})
      super(hash)
      @fake_mess = nil
    end


    def insert_fake(verb, params, desc)
      @fake_mess = Message.from_parts( nil, nil, verb, params, desc )
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

    
    def connected? 
      @fake_mess != nil
    end


    def listen(queue)
      Nebulous.logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}
      yield @fake_mess
    end


    def listen_with_timeout(queue, timeout)
      Nebulous.logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}

      if @fake_mess
        yield @fake_mess
      else
        sleep timeout
        raise Nebulous::NebulousTimeout
      end
    end


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

