# COding: UTF-8

require 'stomp'
require 'json'
require 'time'

require_relative 'stomp_handler'


module Nebulous


  ##
  # Behaves just like StompHandler, except, does nothing and expects no stomp
  # connection
  #
  class StompHandlerNull < StompHandler


    def initialize(hash)
      super
      @fakeMess = MessageNull.from_cache('{}')
    end


    def insert_fake(verb, params, desc)
      @fakeMess = MessageNull.from_parts( nil, nil, verb, params, desc )
    end


    def stomp_connect
      $logger.info(__FILE__) {"Connecting to STOMP (Null)"} 

      @client = true
      self
    end


    def stomp_disconnect
      $logger.info(__FILE__) {"STOMP Disconnect (Null)"}
      @client = nil
      self
    end


    def listen(queue, timeout = nil)
      $logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}
      yield @fakeMess
    end

    alias :listen_with_timeout :listen


    def send_message(queue, nebMess)
      self
    end


    def respond_success(nebMess)
      $logger.info(__FILE__) do 
        "Responded to #{nebMess} with 'success' verb (to Null)"
      end
    end


    def respond_error(nebMess,err,fields=[])
      $logger.info(__FILE__) do
        "Responded to #{nebMess} with 'error' verb: #{err} (to Null)"
      end
    end



  end


end

