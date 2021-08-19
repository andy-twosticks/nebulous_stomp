$: << "./lib" if __FILE__ == $0

require 'nebulous_stomp'
require 'yaml'
require "pry"


##
# A little request-reponse server for the feature test
#
class Gimme

  def initialize(configfile)
    @config   = load_config configfile
    @target   = init_nebulous
    #@listener = NebulousStomp::Listener.new(@target)
    @listener = NebulousStomp::Listener.new("/queue/featuretestreceive")
  end

  def run
    @listener.consume_messages{|msg| reply msg}
  end

  def quit
    @listener.quit
  end

  private

  def load_config(file)
    YAML.load(File.open file)
  end

  def init_nebulous
    NebulousStomp.init @config[:init]
    NebulousStomp.add_target("featuretest", @config[:target] )
  end

  def reply(msg)
    queue, message = 
      case msg.verb
        when "gimmesuccess" 
          msg.respond_with_success

        when "gimmeerror" 
          msg.respond_with_error("the error you wanted")

        when "gimmeprotocol" 
          msg.respond_with_protocol("foo", "bar", "baz")

        when "gimmeempty"
          msg.respond([])

        when "gimmemessage" 
          msg.respond(["weird message body", 12])

        when "gimmebigmessage"
          body = big_body msg.params
          msg.respond body

        else fail "unknown verb #{msg.verb} in Gimme"
      end

    @listener.reply(queue, message)

  rescue
    puts "ERROR: #{$!}" 
    $!.backtrace.each{|e| puts e }
  end

  def big_body(params)
    kb = params.to_f; fail "not a size" if kb == 0

    body = "foo"
    body << "Q" * (1024 * kb)
    body << "bar"

    body
  end

end


if __FILE__ == $0

  begin
    g = Gimme.new('./feature/connection.yaml')
    g.run
    loop { sleep 5 }
  ensure
    g.quit
  end

end
