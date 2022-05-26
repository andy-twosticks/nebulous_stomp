Introduction
============

A little module that implements The Nebulous Protocol, a way of passing data over STOMP between
different systems. Specifically, it allows you to send a message, a *Request* and receive another
message in answer, a *Response*.  (Which is not something STOMP does, out of the box).

This library covers two specific use cases (three if you are picky):

1) Request-Response: a program that consumes incoming messages, works out what message to send in
response, and sends it.

2) Question-Answer: a program that sends a request and then waits for a response; the other end of
the Request-Response use case. We support optional caching of responses in Redis, to speed things up
if your program is likely to make the same request repeatedly within a short time.

3) Since we are talking to Redis, we expose a basic, simple interface for you to talk to it
yourself.


Thanks
======

This code was developed, by me, during working hours at [James Hall & Co.
Ltd](https://www.jameshall.co.uk/). I'm incredibly greatful that they have permitted me to
open-source it.



A Quick Example
===============

Before we get too bogged down, some code. 

    require "nebulous_stomp"

    NebulousStomp.init( my_init_hash )
    NebulousStomp.add_target(:target1, my_target)

    message  = NebulousStomp::Message.new(verb: "ping")
    request  = NebulousStomp::Request.new(:target1, message)
    response = request.send

This example is for the question-answer use case. `response` will contain a NebulousStomp::Message
-- unless the target fails to respond in time, in which case a NebulousStomp::MessageTimeout will
be raised.


The Protocol
============

I natter on about this in far too much detail elsewhere, but the highly condensed version is:

* Every request always gets a response; if you don't get one, then something is wrong at the other
  end.

* Request-response programs consume all messages on the queue that they listen on. They place the
  response on a *different* queue, the name of which is given by the request. 

* Each message has a 'unique' ID; the response has the ID of the request it responds to.

* Messages can "follow the protocol" by being in the form: verb, parameters, descripton. Requests
  *must* be in this form; responses don't have to be.

* The special verb "success" in a response means "I got the message, everything is fine, nothing to
  report here".

* The special verb "error" in a response means something went wrong. The description should say
  what.


Targets
=======

When you have a system running a request-response loop, then the simplest way to proceed is to
assign it a pair of queues on your Stomp server: one for incoming requests, and one for it to post
responses to. 

We call such a system a Target. Any other, question-answer, system (which wants to throw Requests at
that target and get a response) will need to know what those queues are; so we configure a list of
targets at startup.

Note that it is perfectly okay for a target to use more than one request queue (desirable, even,
if some requests will take time to fulfil). But we don't directly support that in Nebulous: a
Target is always one request queue, one response queue. In this case, the simplest way forward is
to define two targets.


Examples
========

Request-Response
----------------

This revisits the example from the start, but with more detail. For completeness, we configure a
Redis server for caching respsonses (which is optional) and show all the config hashes (which
certainly want to come from a config file in practice).

    require "nebulous_stomp"

    host   = {login: "guest", passcode: "guest", host: "10.11.12.13", ssl: false}
    stomp  = {hosts: [host], reliable: false}
    redis  = {host: '127.0.0.1', port: 6379, db: 0}

    config = { stompConnectHash: stomp, 
               redisCOnnectHash: redis, 
               messageTimeout:   5,
               cacheTimeout:     30 }

    target = { sendQueue:      "/queue/in", 
               receiveQueue:   "/queue/out", 
               messageTimeout: 7 }

    NebulousStomp.init(config)
    NebulousStomp.add_target(:target1, target)

    message  = NebulousStomp::Message.new(verb: "ping")
    request  = NebulousStomp::Request.new(:target1, message)

    response1 = request.send
    response2 = request.send

`response1` will be filled from the target; `response2` will be filled from the Redis cache
(provided that line gets called within 30 seconds of the previous line). (Obviously this is
pointless and for example only.)

The stomp hash is passed unchanged to the Stomp gem; the redis hash is passed unchanged to the
Redis gem. See these gems for details about what they should contain.

Message.new takes a single hash as an argument; it accepts a long list of possible keys, but mostly
I imagine you will be using 'verb', 'params', and 'desc'. It's worth also noting 'replyTo', which
sets the queue to reply to; if missing then Request sets it from the Target, of course.

This rather specific example contains three seperate timeout values. The message timeout is the
time we wait for a response before raising MessageTimeout. The value in the config hash is a
default; in this example it is overidden on the target.  The cache timeout is, of course, the time
that the response is kept on the cache. These values can be further overridden for specific
messages.

Often even with a cache set up, you don't want to use it (for requests that trigger database
updates, for example); in which case the method to call is `send_no_cache`.

Question-Answer
---------------

    require "nebulous_stomp"

    NebulousStomp.init(config)
    target = NebulousStomp.add_target(:target1, target)

    listener = NebulousStomp::Listener.new(target)

    listener.consume_messages do |msg|
      begin

        case msg.verb
          when "ping" 
            listener.reply *msg.respond_with_success 
          when "time" 
            listener.reply *msg.respond_with_protocol("timeresponse", Time.now)
          else
            listener.reply *msg.respond_with_error("Bad verb #{msg.verb}")
        end

      rescue
        listener.reply *msg.respond_with_error($!)
      end
    end

    loop { sleep 5 }

This example implements a target that responds to two verbs.  In responce to "ping" it sends a
success verb, indicating it got the message. In response to "time" it sends a "timeresponse" verb
with the current time as a parameter. For any other verb on its receive queue, it responds with an
error verb.

`Listener.new` requires either a Target object or a queue name. This is different from Request,
which can take a target name. You can always retreive a Target object yourself, though, like this:

    target = NebulousParam.get_target(targetname)

If you want to respond with a message that does not follow the verb-parameter-description part of
the protocol, then you can pass an arbitrary message body to `msg.respond()`.

Note the error handling. This is especially important because the body that you pass to the
`consume_messages` method is actually being run in a thread, by the Stomp gem; by default all
errors will be swallowed silently. As you can see, `message.respond_with_error` can take an
exception as a parameter.

Note also, for the same reason, that your program must hold the main thread open while
`consume_messages` is running; if the main thread ends, the program stops.

Redis
-----

    require "nebulous_stomp/redis_helper"

    # ...parameters get set here...

    redis = NebulousStomp::RedisHelper.new

    redis.set(:thing, "thingy")
    redes.set(:gone_in_30_seconds, "thingy", 30)

    value = redis.get(:thing)

    redis.del(:thing)

Obviously this is not so much an example as it is some random calls to RedisHelper. But hopefully
it is fairly self-explanatory.


A list of classes
=================

To help you drill down to the API documentation.  These are the externally-facing classes:

* Listener      -- implements the request-response use case
* Message       -- a Nebulous message
* NebulousStomp -- main class
* RedisHelper   -- implements the Redis use case 
* Request       -- implements the Request-Response use case; a wrapper for Message
* Target        -- represents a single Target
 
These classes are used internally:

* Param            -- helper class to store and return configuration
* RedisHandler     -- internal class to wrap the Redis gem
* RedisHandlerNull -- a "mock" version of  RedisHandler for use in testing
* StompHandler     -- internal class to wrap the Stomp gem
* StompHandlerNull -- a "mock" version of StompHandler for use in testing

You might find the null classes useful in your own tests; both Listener and Request allow the
injection of mock handler objects. You must require them seperately, though.

test -- ignore
