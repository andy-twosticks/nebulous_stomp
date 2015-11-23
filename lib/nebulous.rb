# coding: UTF-8

require 'stomp'
require 'redis'
require 'logger'
require 'devnull'

require 'nebulous/version'
require 'nebulous/param'


##
# A little module that implements the Nebulous Protocol, a way of passing data
# over STOMP between different systems. We also support message cacheing via
# Redis.
#
# Put simply: you can send a message to any other system that supports the
# protocol, with an optional timeout, and get a response.
#
# There are two use cases:
#
# First, sending a request for information and waiting for a response. To do
# this you should create a Nebulous::NebRequest and call methods on it which
# will return a Nebulous::Message, which will have either come from the cache
# or from the remote target.
#
# Second, the other end of the deal: hanging around waiting for requests and
# sending responses. To do this, you need to use the Nebulous::StompHandler
# class, which will again furnish Nebulous::Meessage objects, and allow you to
# create them.
#
# Some configuratuion is required: see Nebulous::init and Nebulous::add_target.
#
# Since you are setting the Redis connection details as part of initialisation,
# you can also use it to connect to Redis, if you want. See
# Nebulous::RedisHandler.
#
module Nebulous


  # Thrown when anything goes wrong.
  class NebulousError < StandardError; end

  # Thrown when nothing went wrong, but a timeout expired.
  class NebulousTimeout < StandardError; end

  # Thrown when we can't connect to STOMP or the connection is lost somehow
  class ConnectionError < NebulousError; end


  # :call-seq: 
  # Nebulous.init(paramHash) -> (nil)
  #
  # Initialise library for use and override default options with any in
  # <paramHash>.
  #
  # The default options are defined in Nebulous::Param.
  #
  def self.init(paramHash={}) 
    Param.set(paramHash)
    return nil
  end


  # :call-seq: 
  # Nebulous.add_target(name, targetHash) -> (nil)
  #
  # Add a nebulous target called <name> with a details as per <targetHash>.
  #
  # <targetHash> must contain a send queue and a receive queue, or a
  # NebulousError will be thrown. Have a look in Nebulous::Param for the
  # default hash you are overriding here.
  #
  def self.add_target(name, targetHash) # -> nil
    Param.add_target(name, targetHash)
    return nil
  end


  ##
  # Set an instance of Logger to log stuff to.
  def self.set_logger(logger)
    Param.set_logger(logger)
  end


  ##
  # :call-seq:
  #   Nebulous.logger.info(__FILE__) { "message" }
  #
  # Return a Logger instance to log things to.
  # If one was not given to Param, return a logger instance that
  # uses a DevNull IO object, that is, goes nowhere.
  #
  def self.logger
    Param.get_logger || Logger.new( DevNull.new )
  end


end

