require 'stomp'
require 'json'
require 'time'

require_relative 'stomp_handler'
require_relative 'message'


module NebulousStomp


  ##
  # Behaves just like StompHandler, except, does nothing and expects no stomp connection
  #
  class StompHandlerNull < StompHandler

    attr_reader :fake_messages

    def initialize(hash={})
      super(hash)
      @fake_messages = []
    end

    def insert_fake(message)
      @fake_messages << message
    end

    def respond_success(nebMess, logid="")
      NebulousStomp.logger.info(__FILE__) do 
        log_helper logid, "Responded to #{nebMess} with 'success' verb (to Null)"
      end
    end

    def respond_error(nebMess,err,fields=[], logid="")
      NebulousStomp.logger.info(__FILE__) do
        log_helper logid, "Responded to #{nebMess} with 'error' verb: #{err} (to Null)"
      end
    end

    def stomp_connect(logid="")
      NebulousStomp.logger.info(__FILE__) {log_helper logid, "Connecting to STOMP (Null)"} 
      @client = true
      self
    end

    def stomp_disconnect(logid="")
      NebulousStomp.logger.info(__FILE__) {log_helper logid, "STOMP Disconnect (Null)"}
      @client = nil
      self
    end
    
    def connected? 
      @fake_messages != []
    end

    def listen(queue, logid="")
      NebulousStomp.logger.info(__FILE__) {log_helper logid, "Subscribing to #{queue} (on Null)"}
      @fake_messages.each{|m| yield m }
    end

    def listen_with_timeout(queue, timeout, logid="")
      NebulousStomp.logger.info(__FILE__) {log_helper logid, "Subscribing to #{queue} (on Null)"}

      if @fake_messages != []
        @fake_messages.each{|m| yield m }
      else
        sleep timeout
        raise NebulousStomp::NebulousTimeout
      end
    end

    def send_message(queue, nebMess, logid="")
      nebMess
    end

    def calc_reply_id; 'ABCD123456789'; end

    private

    def log_helper(logid, message)
      "[N#{logid}|#{Thread.object_id}] #{message}"
    end

  end


end

