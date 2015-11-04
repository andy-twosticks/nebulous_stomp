# COding: UTF-8

require 'stomp'
require 'json'
require 'time'

require_relative 'optionhandler'
require_relative 'stomp_handler'


module Nebulous


  ##
  # Behaves just like StompHandler, except, does nothing and expects no stomp
  # connection
  #
  class StompHandlerNull < StompHandler


    ##
    # Class methods
    #
    class << self


      def body_to_hash (msg)
        hash = nil

        if msg.headers["content-type"] =~ /json/i
          begin
            hash = JSON.parse(msg.body)
          rescue JSON::ParseError, TypeError
            hash = {}
          end

        else
          # We assume that text looks like STOMP headers, or nothing
          hash = {}
          msg.body.split("\n").each do |line|
            k,v = line.split(':', 2).each{|x| x.strip! }
            h[k] = v
          end

        end

        hash
      end


    end
    ##


    def initialize
      @stomp_hash = {}
      @client     = nil

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


    def stomp_listen(queue)
      $logger.info(__FILE__) {"Subscribing to #{queue} (on Null)"}
      yield @fakeMess
    end


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

