require_relative 'target'
require_relative 'stomp_handler'


module NebulousStomp


  class Listener

    attr_reader :queue         # the queue name
    attr_writer :stomp_handler # Insert a StompHandler object for test purposes

    ##
    # When creating a Listener, pass the queue name to listen on.
    #
    # This can be something stringlike, or a Target (in which case we listen on the target's
    # receiving queue).
    #
    # Note: we assume `NebulousStomp.init` has been called.
    #
    def initialize(queue)
      case 
        when queue.respond_to?(:receive_queue) then @queue = queue.receive_queue
        when queue.respond_to?(:to_s)          then @queue = queue.to_s
        else fail ArgumentError, "Unknown object passed as queue"
      end
    end
 
    ##
    # Consume messages from the queue, yielding each.
    #
    # Note that we don't block for input here. Just as with the Stomp gem, and with StompHandler,
    # you will need to take your own measures to ensure that your program does not end when it
    # should be waiting for messages to arrive. The simplest solution is something like:
    #
    #     loop do; pause 5; end
    #
    # Note also that this method runs inside a Thread, and so does the block you pass to it. By
    # default threads do not report errors, so you must arrange to do that yourself.
    #
    def consume_messages
      stomp_handler.listen(@queue) {|msg| yield msg }
    end

    ##
    # Send a message in reply 
    #
    # queue must be a queue name; message must be a Message. 
    #
    def reply(queue, message)
      stomp_handler.send_message(queue, message)
    end

    def quit
      stomp_handler.stomp_disconnect
    end

    private

    def stomp_handler
      @stomp_handler ||= StompHandler.new(Param.get :stompConnectHash)
    end

  end


end

