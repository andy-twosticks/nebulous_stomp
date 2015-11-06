# COding: UTF-8

require 'stomp'
require 'json'
require 'time'


module Nebulous


  class StompHandler

    attr_reader :client


    ##
    # Class methods
    #
    class << self


      ##
      # Parse body and return something Ruby-ish.
      # It might not be a hash, in fact -- it could be an array of hashes.
      #
      def body_to_hash(msg)
        hash = nil

        if msg.headers["content-type"] =~ /json$/i
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


      ##
      # :call-seq:
      #   StompHandler.with_timeout(secs) -> (nil)
      #
      # Run a routine with a timeout.
      #
      # Example:
      #  StompHandler.with_timeout(10) do |r|
      #    sleep 20
      #    r.signal
      #  end
      #
      # Use `r.signal` to signal when the process has finished. You need to
      # arrange your own method of working out whether the timeout fired or not.
      #
      # There is a Ruby standard library for this, Timeout. But there appears to
      # be some argument as to whether it is threadsafe; so, we roll our own. It
      # probably doesn't matter since both Redis and Stomp do use Timeout. But.
      #
      def with_timeout(secs)
        mutex    = Mutex.new
        resource = ConditionVariable.new

        Thread.new do
          mutex.synchronize { yield resource }
        end

        mutex.synchronize { resource.wait(mutex, secs) }

        nil
      end

    end
    ##


    ##
    # Initialise StompHandler by passing the parameter hash.
    #
    def initialize(connectHash)
      @stomp_hash = connectHash
      @client     = nil
    end


    ##
    # Connect to the STOMP client.
    #
    def stomp_connect
      Nebulous.logger.info(__FILE__) {"Connecting to STOMP"} 

      @client = Stomp::Client.new( @stomp_hash )
      raise ConnectionError, "Stomp Connection failed" unless @client.open?

      conn = @client.connection_frame()
      if conn.command == Stomp::CMD_ERROR
        raise ConnectionError, "Connect Error: #{conn.body}"
      end

      self

    rescue => err
      raise ConnectionError, err
    end


    ##
    # Drop the connection to the STOMP Client
    #
    def stomp_disconnect
      if @client
        Nebulous.logger.info(__FILE__) {"STOMP Disconnect"}
        @client.close if @client
        @client = nil
      end

      self
    end


    ##
    # Block for incoming messages on a queue.  Yield each message.
    #
    # Note that the blocking happens in a thread somewhere inside the STOMP
    # client. I have no idea how to join that, and if the examples on the STOMP
    # gem are to be believed, you flat out can't -- the examples just have the
    # main thread sleeping so that it does not termimate while the thread is
    # running.  So to use this make sure that you at some point do something
    # like:
    #     loop; sleep 5; end
    #
    def listen(queue)
      Nebulous.logger.info(__FILE__) {"Subscribing to #{queue}"}

      # Startle the queue into existence. You can't subscribe to a queue that
      # does not exist, BUT, you can create a queue by posting to it...
      @client.publish( queue, "boo" )

      @client.subscribe( queue, {ack: "client-individual"} ) do |msg|
        begin
          yield Message.from_stomp(msg) unless msg.body == 'boo'
          @client.ack(msg)
        rescue =>e
          Nebulous.logger.error(__FILE__) {"Error during polling: #{e}" }
        end
      end

    end


    ##
    # As listen() but give up after yielding a single message, and only wait
    # for a set number of seconds before giving up anyway.
    #
    # Ideally I'd like to DRY this and listen() up, but with this
    # yield-within-a-thread stuff going on, I'm actually not sure how to do
    # that safely.
    #
    def listen_with_timeout(queue, timeout)
      Nebulous.logger.info(__FILE__) do
        "Subscribing to #{queue} with timeout #{timeout}"
      end

      @client.publish( queue, "boo" )

      StompHandler.with_timeout(timeout) do |resource|
        @client.subscribe( queue, {ack: "client-individual"} ) do |msg|

          begin
            @client.ack(msg)
            unless msg.body == 'boo'
              yield Message.from_stomp(msg) 
              resource.signal 
            end
          rescue =>e
            Nebulous.logger.error(__FILE__) {"Error during polling: #{e}" }
          end

        end
      end

    end


    ##
    # Send a Message to a queue; return the message.
    #
    def send_message(queue, nebMess)
      @client.publish(queue, nebMess.stomp_body, nebMess.stomp_header)
      nebMess
    end


    ##
    # Return the neb-reply-id we're going to use for this connection
    #
    def calc_reply_id
      raise ConnectionError, "Client not connected" unless @client

      @client.connection_frame().headers["session"] \
        << "_" \
        << Time.now.to_f.to_s

    end


  end
  ##


end

