# coding: UTF-8

require 'stomp'
require 'redis'
require 'json'

require "nebulous/version"
require 'nebulous/nebrequest'
require 'nebulous/nebresponse'
require 'nebulous/redishandler'


module Nebulous


  class NebulousError   < StandardError; end
  class NebulousTimeout < StandardError; end

  

end

