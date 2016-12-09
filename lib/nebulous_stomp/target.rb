module NebulousStomp


  ##
  # Represents a single Target. Read only.
  #
  # NebulousStomp.add_target returns a Target, or you can retreive one from the config using
  # NebulousStomp.get_target.
  # 
  class Target

    attr_reader :send_queue, :receive_queue, :message_timeout, :name

    VALID_KEYS = %i|sendQueue receiveQueue messageTimeout name|

    ##
    # Create a target.
    #
    # Valid keys for the hash:
    #
    #     * :sendQueue
    #     * :receiveQeue
    #     * :name
    #     * :messageTimeout (optional)
    #
    def initialize(hash)
      fail ArgumentError, "Argument for Target.new must be a hash" unless hash.is_a? Hash

      @send_queue      = hash[:sendQueue]    or fail ArgumentError, "Missing a sendQueue" 
      @receive_queue   = hash[:receiveQueue] or fail ArgumentError, "Missing a receiveQueue"
      @name            = hash[:name]         or fail ArgumentError, "Missing a name"
      @message_timeout = hash[:messageTimeout]

      bad_keys = hash.reject{|k, _| VALID_KEYS.include? k }.keys
      fail ArgumentError, "Bad keys: #{bad_keys.join ' '}" unless bad_keys.empty?
    end

  end


end

