# coding: UTF-8


module Nebulous


  # 'Singleton' 'object' that stores parameters.
  #
  module Param
    extend self


    # Default parameters hash
    ParamDefaults = { stompConnectHash: {},
                      redisConnectHash: {},
                      messageTimeout:   10,
                      cacheTimeout:     120,
                      targets:          {} }

    # Default hash for each target
    TargetDefaults = { sendQueue:      nil,
                       receiveQueue:   nil,
                       messageTimeout: nil }


    # Set the initial parameter string
    # This also has the effect of resetting everything
    # @param p [Hash] Optional hash to override defaults
    #
    def set(p={})
      raise NebulousError, "Invalid initialisation hash" unless p.kind_of?(Hash)

      validate(ParamDefaults, p, "Unknown initialisation hash")

      @params = ParamDefaults.merge(p)
    end


    # Add a Nebulous target
    # Used only by Nebulous::init
    #
    def add_target(n, t)
      raise NebulousError, "Invalid target hash" unless t.kind_of?(Hash)

      validate(TargetDefaults, t, "Unknown target hash")

      raise NebulousError, "Config Problem - Target missing 'send'" \
        if t[:sendQueue].nil?

      raise NebulousError, "Config Problem - Target missing 'receive'" \
        if t[:receiveQueue].nil?

      @params[:targets][n.to_sym] = TargetDefaults.merge(t)
    end


    # Get the whole parameter hash
    # Probably only useful for testing
    # @return [Hash]
    #
    def get_all()
      @params
    end


    # Get a parameter
    # @param p [Symbol] The parameter to retreive
    #
    def get(p)
      @params[p.to_sym]
    end


    # Return a target hash 
    # @param name [Symbol] the name of the target
    # @return [Hash] the hash of parameters for that target
    #
    def get_target(name)
      name = name.to_sym
      x = @params[:targets][name]
      raise NebulousError, "Config problem - unknown target #{name}" if x.nil?
      return x
    end


    # Raise an exception if a hash has any keys not found in an exemplar
    # @private
    #
    def validate(exemplar, hash, message)
      hash.each_key do |k|
        raise NebulousError, "#{message} key '#{k}'" unless exemplar.include?(k)
      end
    end


  end
end

