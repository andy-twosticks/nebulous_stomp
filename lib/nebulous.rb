# coding: UTF-8

require 'stomp'
require 'redis'
require 'json'

require 'nebulous/version'
require 'nebulous/param'
require 'nebulous/nebrequest'
require 'nebulous/nebresponse'
require 'nebulous/redishandler'


module Nebulous


  class NebulousError   < StandardError; end
  class NebulousTimeout < StandardError; end


  # Initialise library for use and override default options
  # See Nebulous::Param for default options
  #
  # @param paramHash [Hash] (optional) parameters to override
  #
  def init(paramHash={})
    Param.set(paramHash)
  end


  # Add a nebulous target. All targets must be added before use.
  # See Nebulous::Param for details of the hash
  #
  # @param name [Symbol] the name of the target
  # @param targetHash [Hash] parameters for that hash
  #
  def add_target(name, targetHash)
    Param.add_target(name, targetHash)
  end


end

