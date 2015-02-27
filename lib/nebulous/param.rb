# coding: UTF-8


module Nebulous


  # 'Singleton' 'object' that stores parameters. Set by Nebulous::init().
  #
  module Param
    extend self


    def set_params(p)
      raise NebulousError, "Invalid initialisation hash" unless p.kind_of?(Hash)

      defaults = { stompConnectHash: {},
                   redisConnectHash: {},
                   messageTimeout:   10,
                   cacheTimeout:     120,
                   targets:          [] }

      validate(defaults, p, "Unknown initialisation hash")

      @params = defaults.merge(p)
    end


    def add_target(n, t)
      raise NebulousError, "Invalid target hash" unless t.kind_of?(Hash)

      defaults = { sendQueue:      nil,
                   receiveQueue:   nil,
                   messageTimeout: nil }

      validate(defaults, p, "Unknown target hash")

      @params[:targets][n.to_sym] = defaults.merge(t)
    end


    def get_param(p)
      @params[p]
    end


    def get_target(name)
      @params[:targets][name.to_sym]
    end


    def validate(exemplar, hash, message)
      hash.each_key do |k|
        raise NebulousError, "#{message} key '#{k}'" unless exemplar.include?(k)
      end
    end


  end
end

