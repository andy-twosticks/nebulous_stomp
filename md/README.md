Nebulous
========

A little module that implements the Nebulous Protocol, a way of passing data
over STOMP between different systems. We also support message cacheing via
Redis.

There are two use cases:

First, sending a request for information and waiting for a response, which
might come from a cache of previous responses, if you allow it. To do
this you should create a Nebulous::NebRequest, which will return a
Nebulous::Message.

Second, the other end of the deal: hanging around waiting for requests and
sending responses. To do this, you need to use the Nebulous::StompHandler
class, which will again furnish Nebulous::Meessage objects, and allow you to
create them.

Some configuratuion is required: see Nebulous.init, Nebulous.add_target &
Nebulous.add_logger.

Since you are setting the Redis connection details as part of initialisation,
you can also use it to connect to Redis, if you want. See
Nebulous::RedisHandler.

a complete list of classes & modules:

* Nebulous
* Nebulous::Param
* Nebulous::NebRequest
* Nebulous::NebRequestNull
* Nebulous::Message
* Nebulous::StompHandler
* Nebulous::StompHandlerNull
* Nebulous::RedisHandler
* Nebulous::RedisHandlerNull

