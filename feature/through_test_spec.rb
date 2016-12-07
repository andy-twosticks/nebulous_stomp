require 'nebulous_stomp'


##
# This is a through test against the JH development stomp server.
# It's really only here to double check that the Stomp gem hasn't moved the 
# goalposts (again).
#
# In order for it to work, the JH RabbitMQ server has to be where we left it. And you need a
# responder listening to /queue/nebulout.test for the 'ping' verb. So this test won't work for you
# out of the box, unless you are me.
#
describe 'through test' do

  def connect_hash
    host = { login:    'guest',
             passcode: 'guest',
             host:     '10.0.0.150',
             port:     61613,
             ssl:      false        }

    {hosts: [host], reliable: false}
  end

  def target_hash
    { sendQueue:    "/queue/nebulous.test",
      receiveQueue: "/queue/nebulous.test.response" }

  end

  def init_stomp
    NebulousStomp.init(stompConnectHash: connect_hash, messageTimeout: 5)
    NebulousStomp.add_target(:target, target_hash)
  end

  ##
  # a little method to receive a message and send one back, for testinng 
  # sending one.
  #
  def qna
    Thread.new do

      begin
        sh = NebulousStomp::StompHandler.new(connect_hash)
        sh.listen_with_timeout( target_hash[:sendQueue], 10 ) do |m| 
          sh.send_message( *m.respond_success )
        end
      ensure
        sh.stomp_disconnect if sh
      end

    end

  rescue
    nil
  end


  let(:request) { NebulousStomp::NebRequest.new(:target, "ping") }

  before do
    init_stomp
  end


  it "sends a request" do
    expect{ request.send_no_cache }.to raise_exception NebulousStomp::NebulousTimeout
  end


  it "receives a response" do
    r = NebulousStomp::NebRequest.new(:target, "ping")
    qna; response = r.send_no_cache

    expect( response ).to be_a_kind_of NebulousStomp::Message
    expect( response.verb ).to eq 'success'
  end

end

