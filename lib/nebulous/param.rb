# coding: UTF-8


module Nebulous


  # 'Singleton' 'object' that stores parameters. Set by Nebulous::init().
  #
  module Param
    extend self


    def set(p)
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

      raise NebulousError, "Config Problem - Target missing 'send'" \
        if t[:sendQueue].nil?

      raise NebulousError, "Config Problem - Target missing 'receive'" \
        if t[:receiveQueue].nil?

      @params[:targets][n.to_sym] = defaults.merge(t)
    end


    def get(p)
      @params[p]
    end


    def get_target(name)
      name = name.to_sym
      x = @params[:targets][name]
      raise NebulousError, "Config problem - unknown target #{name}" if x.nil?
      return x
    end


    def validate(exemplar, hash, message)
      hash.each_key do |k|
        raise NebulousError, "#{message} key '#{k}'" unless exemplar.include?(k)
      end
    end


  end
end

