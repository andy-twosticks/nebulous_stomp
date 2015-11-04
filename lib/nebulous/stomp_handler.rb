# COding: UTF-8

require 'stomp'
require 'json'
require 'time'

require_relative 'optionhandler' #bamf


module Nebulous


  class StompHandler


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
      o = OptionHandler.instance

      h = { login:    o.get(:stompLogin),
            passcode: o.get(:stompPassword),
            host:     o.get(:stompHost),
            port:     o.get(:stompPort),
            ssl:      o.get(:stompSSL) }

      @stomp_hash = { hosts: [h], reliable: false }
      @client     = nil
    end


    def stomp_connect
      $logger.info(__FILE__) {"Connecting to STOMP"} 

      @client = Stomp::Client.new( @stomp_hash )
      raise "Stomp Connection failed" unless @client.open?

      conn = @client.connection_frame()
      if conn.command == Stomp::CMD_ERROR
        raise "Connect Error: #{conn.body}"
      end

      self
    end


    def stomp_disconnect
      $logger.info(__FILE__) {"STOMP Disconnect"}
      @client.close if @client
      @client = nil
      self
    end


    def stomp_listen(queue)
      $logger.info(__FILE__) {"Subscribing to #{queue}"}

      @client.publish( queue, "boo" )

      @client.subscribe( queue, {ack: "client-individual"} ) do |msg|
        begin
          yield Message.from_stomp(msg) unless msg.body == 'boo'
          @client.ack(msg)
        rescue =>e
          $logger.error(__FILE__) {"Error during polling: #{e}" }
        end
      end

      # The above loop is asynchronous; we need to wait.
      # There does not appear to be a better way than:
      loop do; sleep 5; end
    end


    def send_message(queue, nebMess)
      headers = { "content-type" => "application/json",  #bamf
                  "neb-reply-id" => calc_reply_id }

      headers["neb-reply-to"]    = nebMess.reply_to    if nebMess.reply_to
      headers["neb-in-reply-to"] = nebMess.in_reply_to if nebMess.in_reply_to

      message = {verb: nebMess.verb}
      message[:parameters]  = nebMess.params if nebMess.params
      message[:description] = nebMess.desc   if nebMess.desc

      @client.publish(queue, message.to_json, headers)
      self
    end


    def calc_reply_id
      raise "bamf - client not connected error" unless @client

      @client.connection_frame().headers["session"] \
        << "_" \
        << Time.now.to_f.to_s

    end


    def respond_success(nebMess)
      $logger.info(__FILE__) do 
        "Responded to #{nebMess} with 'success' verb"
      end

      send_message( nebMess.reply_to, 
                    Message.in_reply_to(nebMess, 'success') )

    end


    def respond_error(nebMess,err,fields=[])
      $logger.info(__FILE__) do
        "Responded to #{nebMess} with 'error' verb: #{err} (#{err.backtrace.first})"
      end

      send_message( nebMess.reply_to,
                    Message.in_reply_to(nebMess, 'error', fields, err.to_s) )

    end



  end


end

