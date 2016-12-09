require_relative 'target'
require_relative 'stomp_handler'


module NebulousStomp


  ##
  # Implements the Request-Response use case; consume Requests from an input queue and send
  # Responses.
  #
  #     listener = NebulousStomp::Listener.new(target)
  #     listener.consume_messages do |msg|
  #       begin
  #
  #         case msg.verb
  #           when "ping"
  #             listener.reply *msg.respond_with_success
  #           when "time"
  #             listener.reply *msg.respond_with_protocol("timeresponce", Time.now)
  #           else
  #             listener.reply *msg.respond_with_error("Bad verb #{msg.verb}")
  #         end
  #
  #       rescue
  #         listener.reply *msg.respond_with_error($!)
  #       end
  #     end
  #
  #     loop { sleep 5 }
  #
  class Listener

    # the queue name
    attr_reader :queue         

    # Insert a StompHandler object for test purposes
    attr_writer :stomp_handler 

    ##
    # When creating a Listener, pass the queue name to listen on.
    #
    # This can be something stringlike, or a Target (in which case we listen on the target's
    # receiving queue).
    #
    def initialize(queue)
      case 
        when queue.respond_to?(:receive_queue) then @queue = queue.receive_queue
        when queue.respond_to?(:to_s)          then @queue = queue.to_s
        else fail ArgumentError, "Unknown object passed as queue"
      end
    end
 
    ##
    # :call-seq: 
    # listener.consume_message(queue) {|msg| ... }
    #
    # Consume messages from the queue, yielding each.
    #
    # Note that we don't block for input here. Just as with the Stomp gem, and with StompHandler,
    # you will need to take your own measures to ensure that your program does not end when it
    # should be waiting for messages to arrive. The simplest solution is something like:
    #
    #     loop { sleep 5 }
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
    # Queue must be a queue name; message must be a Message. The usual way to get these is from the
    # Message class, for example by calling `message.respond_with_success`.
    #
    def reply(queue, message)
      stomp_handler.send_message(queue, message)
      self
    end

    ##
    # Disconnect from Stomp. 
    #
    # You probably don't need this; Stomp connections are quite short lived.
    #
    def quit
      stomp_handler.stomp_disconnect
      self
    end

    private

    def stomp_handler
      @stomp_handler ||= StompHandler.new(Param.get :stompConnectHash)
    end

  end


end

