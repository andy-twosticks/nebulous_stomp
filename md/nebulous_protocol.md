Nebulous: The Protocol
======================

(It was going to be "The Nebulous Protocol", but that sounds like something with Matt Damon in it.)


Introduction
------------
Project Nebulous is a STOMP client written in ABL, and also the protocol that allows our different
systems, ABL or not, to pass messages. This document, obviously, concentrates on the protocol.

The basic idea is this: one system passes a message, a _request_; and then waits for an answer to
that message, a _response_, from another system. STOMP doesn't explicitly support that; the
protocol does it.

(Note that a request and a response are just notional terms; you might in theory have a request
which provokes a response which provokes another response in return, in which case the second
message is both a response and a request, and the terms get rather less useful.)


The Protocol
------------
Let's start with the actual protocol, the rules. They won't make sense without reading the rest of the document, but:

1. Every valid request (that is, every message with an identifiable verb other than "success" or
   "error") will always generate a response. If the handling routine cannot generate a valid
   response, or if there is no routine to handle the verb in question, then the response should be
   the error verb. If no response is required, you should still receive the success verb.

2. You should expect that requests that do not have a verb will not be responded to or even
   understood. (However, there is no general requirement for message bodies to follow the verb /
   parameters / description format. If you have a program that sends a request and waits for a
   response, the format of that response is outside the remit of The Protocol.)

3. If a request has the _neb-reply-to_ header, the response should use that as a destination;
   otherwise it should be sent to the same destination that the request was sent to.

4. If the request has a _neb-reply-id_ header, then the response should set the _neb-in-reply-to_
   header to that.

5. The request may specify the content type of a response (JSON or text) by it's own content type.
   That is, if a response can be in either form, it should take the form of the request as an
   indication as which to use.

6. A given queue that is the target of requests within The Protocol will be for only one system or
   common group of systems. They may consume (ACK) messages sent to it even if they do not have the
   facility to process them.  If multiple systems share a queue, they should understand that
   messages will be consumed from it at random.


Components
----------
By way of an explanation of the above section.

### Headers ###

STOMP allows you to define custom headers. We have three. 

* _neb-reply-to_ is may be set on a request to the destination that any response should be posted
  to. (See rule 3.)

* _neb-reply-id_ may be set on a request to an arbitrary string to help you identify the response.

* _neb-in-reply-to_ is set on a response and contains the neb-reply-id of the request. (see rule 4.)

### Message Body ###

The Protocol specifies a format for the message body. It consists of three fields:

* _verb_ is the keyword that tells the receiving system how to process the message.

* _parameters_ is an arbitrary field that is context-dependant on verb. The routine that handles
  the verb is expected to be able to parse it. It is optional.

* _description_ is a text field and can contain anything. It is optional.

Nebulous supports message bodies in either JSON (in which case parameters is probably an array) or
plain text (in which case it expects to find the fields formatted in the same way as STOMP headers:
seperated by line breaks, where each line consists of the field name, a colon, and the value).

There are a couple of special verbs:

* _success_ as a verb in a response is used when no information needs to be returned except that
  the request operation went ahead without problem.

* _error_ as a verb is used when the requested operation failed. The expectation is that you will
  put an error message in the description field; you can use parameters as you see fit, of course.


Notes on usage
--------------

There are two use cases here. The first (let's call it _Q & A_) is when a process needs information
and sends a request, then waits for a response. The second (let's call it _Responder_) is at the
other end of that process; it camps onto one or more queues waiting for requests, and arranges for
responses to be sent.

### Responder ###

Let's talk about the Responder use case first, since it's simpler; we've basically been talking
about it for the whole of this document. You'll need to designate a queue for incoming requests on
any given system. You might want more than one; in ABL, where traffic jams are likely because I
can't just spawn up a thread to handle each incoming message, my current thinking is to have two
incoming queues, one for reqests that take a few seconds, and another for requests that take
longer. 

Remember that rule 6 says that any messages that go to a queue like this will be consumed without
concern for whether the message will make sense to the system in question; this is basically there
so that the ABL code can split up the process of grabbing new messages from the process of working
out what they are and how to answer them. 

But the simplicity is appealing, regardless: post to this queue and the Responder that looks after
this system will process it. Rule 1 guarantees you an answer so long as the system is up, so if you
don't get one then either the target system is down or it's too busy to respond.

The expectation is that the Responder system should use the verb of the message to control how it
is dealt with. The parameters field is verb-specific; the combination of verb, expected parameters,
and the nature of the returned message form a sort of contract, ie "verb x always expects
parameters like this, and always behaves like that in response". This is partly implied by Rule 2,
I think.

### Q & A ###

The Q & A use case is more interesting since it's what the whole thing is for, but some of it
really falls outside of The Protocol.

In theory, Rule 3 says you can fail to use _neb-reply-to_ and pick up your response from the same
queue you posted the message to. But rule 6 says that if you do that you don't have any guarantee
at all of getting your message; the Responder will take it. So for practical purposes you almost
always *have* to set a reply-to queue in your request. 

Likewise, Rule 4 says that _neb-reply-id_ is optional. But in practice you should almost certainly
set it. Yes, you can specify a brand new queue that is unique to your request -- or probably
unique, anyway -- but it turns out that some message servers, our RabbitMQ included, don't let you
subscribe to a queue that doesn't exist. It's easy enough to create a queue: you just send a
message to it. But now there are two messages in that queue (or more if turns out that you've got
some queue namespace collision after all) and you have to pick your response from it, and the
easiest way is to set a reply id.

So let's assume a median worst case: you're posting a request to a Responder queue with a reply-id
set to something hopefully unique, and reply-to set to a common queue that many processes use to
pick up replies. There are two challenges here: first, working out which message is yours; second,
avoiding consuming those messages that are not.

For a unique reply-id you could do worse than starting with the session ID that STOMP returns when
you send a CONNECT frame; clearly the message server thinks that is unique, and it should know. In
the Ruby Stomp gem, you can get it with `client.connection_frame().headers["session"]` where client
is your `Stomp::Client` instance; in my ABL jhstomp.p library call `get_session_id()`.

Now that you have a good reply ID you can tell which is yours by Rule 4; just test the
_neb-in-reply-to_ header of each message. 

The second problem, of avoiding consuming messages that don't match your reply-id, is handled by
careful use of STOMP. If when subscribing you set the header `ack:client-individual`, then you must
manually acknowledge each message you want to consume with an ACK frame.

Finally, you get to handle the response. Rule 1 says that it will either be an error verb, a
success verb ... or something else specific to the verb. The nature of messages in responses is
really outside of The Protocol; you are free to use the verb / parameters / description format if
you wish. Again, I'm assuming that a given verb will always require the same parameters and return
the same message. I think that to do otherwise would be very confusing. But The Protocol can't
enforce that. 

Note also that while The Protocol says that a request should always result in a response, there is
nothing to say that the sender of the request should care -- say, in the example of a request that
results in a report being emailed, which takes 20 minutes. 

