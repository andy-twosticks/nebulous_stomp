require 'stomp'
require 'json'
require 'time'

module NebulousStomp


  ##
  # A Class to deal with talking to STOMP via the Stomp gem.
  #
  # You shouldn't ever need to instantiate this yourself.  For listening to messages and
  # responding, use NebulousStomp::Listener.  For sending a message and waiting for a response, you
  # want NebulousStomp::Request (passing it a NebulousStomp::Message).
  #
  class StompHandler

    attr_reader :conn


    ##
    # Initialise StompHandler by passing the parameter hash.
    #
    def initialize(connectHash=nil, testConn=nil)
      @stomp_hash = connectHash ? connectHash.dup : nil
      @test_conn  = testConn
      @conn       = nil
    end

    ##
    # Connect to the STOMP client.
    #
    def stomp_connect(logid="")
      return self unless nebulous_on?
      NebulousStomp.logger.info(__FILE__) {log_helper logid, "Connecting to STOMP"} 

      @conn = @test_conn || Stomp::Connection.new(@stomp_hash)
      fail ConnectionError, "Stomp Connection failed" unless @conn.open?()

      cf = @conn.connection_frame()
      if cf.command == Stomp::CMD_ERROR
        fail ConnectionError, "Connect Error: #{cf.body}"
      end

      self
    rescue => err
      raise ConnectionError, err
    end

    ##
    # Drop the connection to the STOMP Client
    #
    def stomp_disconnect(logid="")
      if @conn
        NebulousStomp.logger.info(__FILE__) {log_helper logid, "STOMP Disconnect"}
        @conn.disconnect() if @conn
        @conn = nil
      end

      self
    end

    ##
    # return true if we are connected to the STOMP server
    #
    def connected?
      !!(@conn && @conn.open?())
    end

    ##
    # return true if Nebulous is turned on in the parameters
    #
    def nebulous_on?
      !!(@stomp_hash && !@stomp_hash.empty?)
    end

    ##
    # Block for incoming messages on a queue.  Yield each message.
    #
    # This method automatically consumes every message it reads, since the assumption is that we
    # are using it for the request-response use case.  If you don't want that, try
    # listen_with_timeout(), instead.
    #
    # It runs in a thread; if you want it to stop, just stop waiting for it.
    #
    def listen(queue, logid="")
      return unless nebulous_on?
      NebulousStomp.logger.info(__FILE__) {"Subscribing to #{queue}"}

      Thread.new do
        stomp_connect unless @conn

        # Startle the queue into existence. You can't subscribe to a queue that
        # does not exist, BUT, you can create a queue by posting to it...
        @conn.publish( queue, "boo" )
        @conn.subscribe( queue, {ack: "client-individual"} )

        loop do
          begin
            msg = @conn.poll()
            log_msg(msg, logid)
            ack(msg)

            yield Message.from_stomp(msg) \
              unless msg.body == 'boo' \
                  || msg.respond_to?(:command) && msg.command == "ERROR"

          rescue =>e
            NebulousStomp.logger.error(__FILE__) {log_helper logid, "Error during polling: #{e}"}
          end
        end

      end # of thread

    end

    ##
    # As listen() but give up after yielding a single message, and only wait for a set number of
    # seconds before giving up anyway.
    #
    # The behaviour here is slightly different than listen(). If you return true from your block,
    # the message will be consumed and the method will end.  Otherwise it will continue until it
    # sees another message, or reaches the timeout.
    #
    # Put another way, since most things are truthy -- if you want to examine messages to find the
    # right one, return false from the block to get another.
    #
    def listen_with_timeout(queue, timeout, logid="")
      return unless nebulous_on?
      NebulousStomp.logger.info(__FILE__) {log_helper logid, "Subscribing to #{queue} with timeout #{timeout}"}

      stomp_connect unless @conn
      id = rand(10000)

      @conn.publish( queue, "boo" )
      
      done = false
      time = Time.now

      @conn.subscribe(queue, {ack: "client-individual"}, id) 
      NebulousStomp.logger.debug(__FILE__) {log_helper logid, "subscribed"}

      loop do
        begin
          msg = @conn.poll()

          if msg.nil?
            # NebulousStomp.logger.debug(__FILE__) {log_helper logid, "Empty message, sleeping"}
            sleep 0.2
          else
            log_msg(msg, logid)

            if msg.respond_to?(:command) && msg.command == "ERROR"
              NebulousStomp.logger.error(__FILE__) {log_helper logid, "Error frame: #{msg.inspect}" }
              ack(msg)
            elsif msg.respond_to?(:body) && msg.body == "boo"
              ack(msg)
            else
              done = yield Message.from_stomp(msg) 
              if done
                NebulousStomp.logger.debug(__FILE__) {log_helper logid, "Yield returns true"}
                ack(msg)
              end
            end

          end # of else

        rescue =>e
          NebulousStomp.logger.error(__FILE__) {log_helper logid, "Error during polling: #{e}"}
        end

        break if done

        if timeout && (time + timeout < Time.now)
          NebulousStomp.logger.debug(__FILE__) {log_helper logid, "Timed out"}
          break
        end
      end

      NebulousStomp.logger.debug(__FILE__) {log_helper logid, "Out of loop. done=#{done}"}

      @conn.unsubscribe(queue, {}, id)

      fail NebulousTimeout unless done
    end

    ##
    # Send a Message to a queue; return the message.
    #
    def send_message(queue, mess, logid="")
      return nil unless nebulous_on?
      fail NebulousStomp::NebulousError, "That's not a Message" \
        unless mess.respond_to?(:body_for_stomp) \
            && mess.respond_to?(:headers_for_stomp)

      stomp_connect unless @conn

      headers = mess.headers_for_stomp.reject{|k,v| v.nil? || v == "" }
      @conn.publish(queue, mess.body_for_stomp, headers)
      mess
    end

    ##
    # Return the neb-reply-id we're going to use for this connection
    #
    def calc_reply_id
      return nil unless nebulous_on?
      fail ConnectionError, "Client not connected" unless @conn

      @conn.connection_frame().headers["session"] \
        << "_" \
        << Time.now.to_f.to_s

    end

    private

    def log_helper(logid, message)
      "[#{logid}|#{Thread.object_id}] #{message}"
    end

    def log_msg(message, logid)
      NebulousStomp.logger.debug(__FILE__) do
        b = message.respond_to?(:body) ? message.body.to_s[0..30] : nil
        h = message.respond_to?(:headers) ? message.headers.select{|k,v| k.start_with?("neb-") }.to_h : {}
        log_helper logid, "New message neb: #{h} body: #{b}"
      end
    end

    # Borrowed from Stomp::Client.ack()
    def ack(message, headers={})

      case @conn.protocol
        when Stomp::SPL_12
          id = 'ack'
        when Stomp::SPL_11
          headers = headers.merge(:subscription => message.headers['subscription'])
          id = 'message-id'
        else
          id = 'message-id'
      end

      @conn.ack(message.headers[id], headers)
    end

  end # StompHandler


end

