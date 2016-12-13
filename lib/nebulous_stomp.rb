require 'stomp'
require 'redis'
require 'logger'
require 'devnull'

require 'nebulous_stomp/version'
require 'nebulous_stomp/param'
require 'nebulous_stomp/message'
require 'nebulous_stomp/target'
require 'nebulous_stomp/listener'
require 'nebulous_stomp/request'
require 'nebulous_stomp/stomp_handler'
require 'nebulous_stomp/redis_handler'


##
# NebulousStomp
# =============
#
# A little module that implements The Nebulous Protocol, a way of passing data over STOMP between
# different systems. Specifically, it allows you to send a message, a *Request*, and receive another
# message in answer, a *Response*.  (Which is not something STOMP does, out of the box).
#
# This library covers two specific use cases (three if you are picky):
#
#     1) Request-Response: a program that consumes incoming messages, works out what message to
#        send in response, and sends it.
#
#     2) Question-Answer: a program that sends a request and then waits for a response; the other
#        end of the Request-Response use case. We support optional caching of responses in Redis,
#        to speed things up if your program is likely to make the same request repeatedly within a
#        short time.
#
#     3) Since we are talking to Redis, we expose a basic, simple interface for you to talk to it
#        yourself.
#
# These are the externally-facing classes:
#
#     * Listener      -- implements the request-response use case
#     * Message       -- a Nebulous-Stomp message
#     * NebulousStomp -- main class
#     * RedisHelper   -- implements the Redis use case
#     * Request       -- implements the Request-Response use case; a wrapper for Message
#     * Target        -- represents a single Target
#
# These classes are used internally:
#
#     * Param            -- helper class to store and return configuration
#     * RedisHandler     -- internal class to wrap the Redis gem
#     * RedisHandlerNull -- a "mock" version of  RedisHandler for use in testing
#     * StompHandler     -- internal class to wrap the Stomp gem
#     * StompHandlerNull -- a "mock" version of StompHandler for use in testing
#
module NebulousStomp


  # Thrown when anything goes wrong.
  class NebulousError < StandardError; end

  # Thrown when nothing went wrong, but a timeout expired.
  class NebulousTimeout < StandardError; end

  # Thrown when we can't connect to STOMP or the connection is lost somehow
  class ConnectionError < NebulousError; end

  ##
  # :call-seq: 
  # NebulousStomp.init(paramHash) -> (nil)
  #
  # Initialise library for use and override default options with any in <paramHash>.
  #
  # The default options are defined in Nebulous::Param.
  #
  def self.init(paramHash={}) 
    Param.set(paramHash)
    nil
  end

  ##
  # :call-seq: 
  # NebulousStomp.add_target(name, targetHash) -> Target
  #
  # Add a Nebulous target called <name> with a details as per <targetHash>.
  #
  # <targetHash> must contain a send queue and a receive queue, or a NebulousError will be
  # raised. Have a look in NebulousStomp::Target for the default hash you are overriding here.
  #
  # Note that Param expects the target hash to have a :name key. We don't; we add it in.
  #
  def self.add_target(name, targetHash) 
    t = NebulousStomp::Target.new targetHash.merge(name: name)
    Param.add_target(t)
    t
  end

  ##
  # :call-seq:
  #   NebulousStomp.get_target(name) # -> Target
  #
  # Given a target name, return the Target object.
  #
  def self.get_target(name)
    Param.get_target(name)
  end

  ##
  # :call-seq:
  #   NebulousStomp.set_logger(Logger.new STDOUT)
  #
  # Set an instance of Logger to log stuff to.
  #
  def self.set_logger(logger)
    Param.set_logger(logger)
  end

  ##
  # :call-seq:
  #   NebulousStomp.logger.info(__FILE__) { "message" }
  #
  # Return a Logger instance to log things to. If one was not given to Param, return a logger
  # instance that uses a DevNull IO object, that is, goes nowhere.
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

