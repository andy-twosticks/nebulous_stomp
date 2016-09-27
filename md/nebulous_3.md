Some Thoughts on Nebulous 3
===========================

Look, this code is not pretty.  It was made by squishing together two different bits of code -- the
code that did the Q&A bit from one place and the code that did request-response from another place
-- and duct taping them together until they didn't squeak too much when you waved them about.
It works, but it's kinda a minefield.

Fixing this will be a breaking change.


Some example code for usage of Nebulous-stomp 3.0.

Q&A
---

    require 'nebulous-stomp'

    msg = NebulousStomp::Message.new(verb, params, desc, replyqueue)
    response = NebulousStomp::Request.new(msg).send_no_cache

Request-response
----------------

    require 'nebulous-stomp'

    listener = NebulousStomp::Listener.new(queue)

    listener.consume do |msg|

      # Process the message here

      if foo
        # Protocol message for an error
        listener.reply NebulousStomp::Message.reply_with_protocol(msg, 'error', nil, 'Foo!!')
      else
        # Non-protocol message body reply
        listener.reply NebulousStomp::Message.reply_with(msg, body)
      end

    end


Note that just based on this, the following breaking changes:

* Parameter order for Message.new improved
* NebRequest is replaced by Request which gets Message injected into it
* New Listener class to replace directly calling StompHandler
* Message.in_reply_to replaced with reply_with and reply_with_protocol

