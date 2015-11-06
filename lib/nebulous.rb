# coding: UTF-8

require 'stomp'
require 'redis'

require 'nebulous/version'
require 'nebulous/param'


# A little module that provides request-and-response over STOMP, with optional
# cacheing using Redis. A specific "Nebulous Protocol" is used to handle this.
#
# Put simply: you can send a message to any other system that supports the
# protocol, with an optional timeout, and get a response.
#
# Use Nebulous::init and Nebulous::add_target to set it up; then create a
# Nebulous::Nebrequest, which will return a Nebulous::Nebresponse.
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


end

