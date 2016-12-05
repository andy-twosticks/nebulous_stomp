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

### v2 ###

    require 'nebulous-stomp'

    response = NebulousStomp::NebRequest.new(target, verb, params, desc).send_no_cache


### v3 ###

    require 'nebulous-stomp'

    msg = NebulousStomp::Message.new(verb: verb, params: params, desc: desc)
    response = NebulousStomp::Request.new(target, msg).send_no_cache

* We can now create a Message directly. Message.new uses the hash form (which it does now; we'll
  just have to make it public again and move front-end logic into it to deal with different
  combinations of arguments).

* Request wraps a Message with Q&A logic and returns a response (still a Message). If (as in the
  example) a message does not have a reply_to, Request creates a *new* message based on the message
  it is given, plus the reply_to from the target, and sends that.

* NebRequest is gone. A dead parrot.

* We should expose target as a class to help the users' code stay clean if they want to, eg, pass a
  reply-to into Message.new.  Request.new should take either a target name or a Target. 

* We should not mandate that any targets exist. Request needs a target, but if the user wants to
  give it one via Target.new, that should be fine.

* All classes become (remain?) read-only: their objects do not change (external?) state once
  created.



Request-response
----------------

### v2 ###

    require 'nebulous-stomp'

    hash = { login: login,
             passcode: password,
             host: host,
             port: port,
             ssl: ssl }

    stomp_handler = NebulousStomp.StompHandler.new(hash)
    stomp_handler.stomp_connect

    stomp_handler.listen(queue) do |msg|
      # Process the message here

      # Protocol message for an error
      stomp_handler.send_message *msg.respond_error($!)

      # Protocol message for success
      stomp_handler.send_message *msg.respond_success

      # Non-protocol message body reply -- you can't!
    end


### v3 ###

    require 'nebulous-stomp'

    listener = NebulousStomp::Listener.new(queue)

    listener.consume do |msg|

      # Process the message here

      # Protocol message for an error
      listener.reply *msg.respond_with_protocol('error', nil, 'Foo!!')
      # or
      listener.reply *msg.respond_with_error($!)

      # Protocol message for success
      listener.reply *msg.respond_with_success

      # Non-protocol message body reply
      listener.reply *msg.respond(body)

    end

* R-R still does not really use targets. Listener.new should take a Target or a target name, in
  which case it uses the request queue. But that's it. Conversely we should ensure that we don't
  NEED to set up targets in the R-R use case.

* Message.respond_whatever changes to Message.respond_with_whatever, for clarity. As now these
  messages return [queue, message] where message is a new Message object. They should be trivial
  wrappers for Message.new, or at worst, some other static creation method. (Message.in_reply_to is
  hopefully redundant?)

* New Listener class wraps up StompHandler functionality for the R-R use case. consume yields each
  message on the queue; reply takes a Message and sends it.  Seems as if Listener and Request needs
  to share some common code.

* Message can now handle the user creating a message which does not follow the protocol, which
  apparently we can't do now? Major omission.


Redis
-----

Remembering that we offer users an "easy" way to read and write to Redis, as a side-benefit.

### v2 ###

    handler = NebulousStomp::RedisHandler.new(NebulousStomp::Param.get :redisConnectHash)

    # set
    handler.connect unless handler.connected?
    handler.set( key.is_a? String ? key : key.to_json, value.to_json )

    # set with timeout
    handler.connect unless handler.connected?
    handler.set( key.is_a? String ? key : key.to_json, value.to_json, ex: timeout )

    # get
    handler.connect unless handler.connected?
    begin
      json  = handler.get(key.is_a? String ? key : key.to_json)
      value = JSON.parse(key, :symbolize_names => true)
    rescue JSON::ParserError
      value = nil
    end

    handler.quit


### v3 ###

    # set
    NebulousStomp.redis_set(key, value)

    # set with timeout
    NebulousStomp.redis_set(key, value, timeout)

    # get
    value = NebulousStomp.redis_get(key)


* New redis_set method takes key, value, optional timeout.

* New redis_get method takes key and returns value.


Summary of Changes
------------------

* New Target class; Param.get_target and get_all now returns Target objects rather than a hash for
  each target; New method NebulousStomp.get_target wraps Param.get_target.

* New Request class containing the Q&A logic from NebRequest: accepts a Message on creation;
  returns another Message for the response. Should allow injection via attr_writer for testing.
  Maybe we don't need a RequestNull?

* New Listener class wraps StompHandler for the request-response use-case: accepts a queue (or a
  target) when created; consume_messages method yields each message from the queue, consuming it;
  reply method takes a Message and sends it to its reply_to.

* Given the Listener class, StompHandler should no longer look at Param (it only does it in one
  place anyway).

* Message class changes: new method becomes public again, presumably we can lose some of those
  creator static methods; it should be possible to create a Message without a reply_to, or which
  does not follow The Protocol; respond_blah becomes respond_with_blah and returns a Message.

* Message.in_reply_to now takes a Message and a hash. Message.from_parts is no longer a thing. New
  methods #respond and respond_protocol.

* NebRequest to be removed.

* NebulousStomp to have new redis_get, redis_set methods as above.

* To facilitate testing of Listener, StompHandlerNull needs to support multiple fake messages;
  StompHandlerNull.listen should return each and then stop.

* All of the above needs test coverage, of course. through_test needs changing to reflect the new
  API.

* And... we need a README with a tutorial of the order of Pod4. 

