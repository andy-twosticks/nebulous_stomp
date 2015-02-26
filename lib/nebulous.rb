# coding: UTF-8

require 'stomp'
require 'redis'
require 'json'
require "nebulous/version"

require_relative 'redis' #bamf, wrong


module Nebulous


  class NebulousError   < StandardError; end
  class NebulousTimeout < StandardError; end

  

end

