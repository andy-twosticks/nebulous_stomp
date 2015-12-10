# coding: UTF-8

require 'stomp'
require 'redis'
require 'logger'
require 'devnull'

require 'nebulous/version'
require 'nebulous/param'
require 'nebulous/message'
require 'nebulous/nebrequest'
require 'nebulous/stomp_handler'
require 'nebulous/redis_handler'


##
# A little module that implements the Nebulous Protocol, a way of passing data
# over STOMP between different systems. We also support message cacheing via
# Redis.
#
# There are two use cases:
#
# First, sending a request for information and waiting for a response, which
# might come from a cache of previous responses, if you allow it. To do
# this you should create a Nebulous::NebRequest, which will return a
# Nebulous::Message.
#
# Second, the other end of the deal: hanging around waiting for requests and
# sending responses. To do this, you need to use the Nebulous::StompHandler
# class, which will again furnish Nebulous::Meessage objects, and allow you to
# create them.
#
# Some configuratuion is required: see Nebulous.init, Nebulous.add_target &
# Nebulous.add_logger.
#
# Since you are setting the Redis connection details as part of initialisation,
# you can also use it to connect to Redis, if you want. See
# Nebulous::RedisHandler.
#
# a complete list of classes & modules:
#
# * Nebulous
# * Nebulous::Param
# * Nebulous::NebRequest
# * Nebulous::NebRequestNull
# * Nebulous::Message
# * Nebulous::StompHandler
# * Nebulous::StompHandlerNull
# * Nebulous::RedisHandler
# * Nebulous::RedisHandlerNull
#
# If you want the null classes, you must require them seperately.
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


  ##
  # :call-seq:
  #     Nebulous.on? -> Boolean
  #
  # True if Nebulous is configured to be running
  #
  def self.on?
    h = Param.get(:stompConnectHash)
    !(h.nil? || h.empty?)
  end


  ##
  # :call-seq:
  #     Nebulous.redis_on? -> Boolean
  #
  # True if the Redis cache is configured to be running
  #
  def self.redis_on?
    h = Param.get(:redisConnectHash)
    !(h.nil? || h.empty?)
  end


end

