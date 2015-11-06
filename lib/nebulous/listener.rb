# COding: UTF-8

require_relative 'message_null'


module Nebulous


  class Listener


    ##
    # class methods 
    #
    class << self

      ##
      # Responder classes register themselves with Deliverance by calling this.
      #
      def register(responder)   #bamf
        # Responder is a _class_, not an object. We can't use kind_of
        raise "#{responder.name} doesn't look like a responder to me!" \
          unless responder.ancestors.include? Deliverance::Responder

        @responders ||= []
        @responders << responder
      end


      def responders; @responders; end

    end
    ##
    

    ##
    # To start Listener, you need to inject a StompHandler instance.
    # 
    def initialize(stompHandler)
      o = OptionHandler.instance

      @stomp_handler = stompHandler

      @threads  = []
      @queue    = o.get(:queue)
      @sleep    = o.get(:sleep)
      @dev_mode = o.get(:devMode)
      
      if o.get(:fakeVerb)
        @stomp_handler = StompHandlerNull.new
        @stomp_handler.insert_fake( o.get(:fakeVerb), 
                                    o.get(:fakeParams), 
                                    o.get(:fakeDesc) )
      end
    end


    ##
    # Perform the actual listen-and-respond loop.
    #
    def go
      @stomp_handler.stomp_connect
      @stomp_handler.stomp_listen(@queue){|msg| handle_message(msg) }

    rescue => e
      $logger.error(__FILE__) {e.to_s}
      e.backtrace.take(3).each{|x| $logger.error(__FILE__){x.prepend('   ')} }
    ensure
      @stomp_handler.stomp_disconnect
      self
    end


    private


    ##
    # Given a NebMessage, launch each registered Responder which claims to deal
    # with that verb.
    #
    def handle_message(msg)
      log_message(msg)

      resps = Listener.responders.select {|x| x.verbs.include? msg.verb }
      raise "No responders known for this message" if resps.empty?

      resps.each {|resp| launch_responder(resp, msg) }
      sleep @sleep if @sleep

    rescue => e
      @stomp_handler.respond_error(msg, e)
    end


    ##
    # Launch a responder
    #
    def launch_responder(responder, msg)
      $logger.info(__FILE__) do 
        "Launching #{responder.name} and passing it message #{msg}" 
      end

      update_threads

      @threads << Thread.new do

        begin
          responder.new(@stomp_handler, @dev_mode).go(msg)
        rescue => e
          $logger.error(__FILE__) {"Responder #{responder.name}: Error: #{e}"}
          e.backtrace.take(3).each do |x| 
            $logger.error(__FILE__){ x.prepend('  ') }
          end
        end

      end

      self
    end


    def update_threads
      # we can now count alive threads and throttle! At some point... bamf
      @threads.delete_if{|t| ! t.alive? }
    end


    def log_message(msg)
      $logger.debug(__FILE__) {"Caught message: #{msg}"}
    end


  end


end

