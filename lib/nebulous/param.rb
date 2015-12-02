# coding: UTF-8


module Nebulous


  ##
  # 'Singleton' 'object' that stores parameters.
  #
  module Param
    extend self


    # Default parameters hash
    ParamDefaults = { stompConnectHash: {},
                      redisConnectHash: {},
                      messageTimeout:   10,
                      cacheTimeout:     120,
                      logger:           nil,
                      targets:          {} }

    # Default hash for each target
    TargetDefaults = { sendQueue:      nil,
                       receiveQueue:   nil,
                       messageTimeout: nil }


    ##
    # Set the initial parameter string. This also has the effect of resetting
    # everything. 
    #
    # Parameters default to Param::ParamDefaults. keys passed in parameter p to
    # ovveride those defaults must match, or a NebulousError will result.
    #
    # This method is only called by Nebulous::init().
    #
    def set(p={})
      raise NebulousError, "Invalid initialisation hash" unless p.kind_of?(Hash)

      validate(ParamDefaults, p, "Unknown initialisation hash")

      @params = ParamDefaults.merge(p)
    end


    ##
    # Add a Nebulous target.  Raises NebulousError if anything looks screwy.
    #
    # Parameters:
    #  n -- target name
    #  t -- hash, which must follow the pattern set by Param::TargetDefaults
    #
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



    ##
    # Set a logger instance
    #
    def set_logger(lg)
      raise NebulousError unless lg.kind_of?(Logger) || lg.nil?
      @logger = lg
    end


    ##
    # Get the logger instance
    #
    def get_logger; @logger; end


    ##
    # Get the whole parameter hash. Probably only useful for testing.
    #
    def get_all()
      @params
    end


    ##
    # Get a the value of the parameter with the key p.
    #
    def get(p)
      @params[p.to_sym]
    end


    ##
    # Given a target name, return the corresponding target hash 
    #
    def get_target(name)
      name = name.to_sym
      x = @params[:targets][name]
      raise NebulousError, "Config problem - unknown target #{name}" if x.nil?
      return x
    end


    ##
    # Raise an exception if a hash has any keys not found in an exemplar
    #
    # (Private method, only called within Param)
    #
    def validate(exemplar, hash, message)
      hash.each_key do |k|
        raise NebulousError, "#{message} key '#{k}'" unless exemplar.include?(k)
      end
    end


    ##
    # reset all parameters -- probably only useful for testing
    #
    def reset
      @params = {}
      @logger = nil
    end


  end
end

