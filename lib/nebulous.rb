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


  def init(paramhash)
    Param.set(paramhash)
  end


  def add_target(name, targetHash)
    Param.add_target(name, targetHash)
  end


end

