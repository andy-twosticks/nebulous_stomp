require 'stomp'
require 'json'
require 'time'

require_relative 'stomp_handler'
require_relative 'message'


module NebulousStomp


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


    def insert_fake(message)
      @fake_mess = message
    end


    def stomp_connect
      NebulousStomp.logger.info(__FILE__) {"Connecting to STOMP (Null)"} 

      @client = true
      self
    end


    def stomp_disconnect
      NebulousStomp.logger.info(__FILE__) {"STOMP Disconnect (Null)"}
      @client = nil
      self
    end

    
    def connected? 
      @fake_mess != nil
    end


    def listen(queue)
      NebulousStomp.logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}
      yield @fake_mess
    end


    def listen_with_timeout(queue, timeout)
      NebulousStomp.logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}

      if @fake_mess
        yield @fake_mess
      else
        sleep timeout
        raise NebulousStomp::NebulousTimeout
      end
    end


    def send_message(queue, nebMess)
      nebMess
    end


    def respond_success(nebMess)
      NebulousStomp.logger.info(__FILE__) do 
        "Responded to #{nebMess} with 'success' verb (to Null)"
      end
    end


    def respond_error(nebMess,err,fields=[])
      NebulousStomp.logger.info(__FILE__) do
        "Responded to #{nebMess} with 'error' verb: #{err} (to Null)"
      end
    end


    def calc_reply_id; 'ABCD123456789'; end


  end


end

