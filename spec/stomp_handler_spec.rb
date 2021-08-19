require 'time'

require 'nebulous_stomp/stomp_handler'
require 'nebulous_stomp/message'

require_relative 'helpers'

include NebulousStomp


RSpec.configure do |c|
  c.include Helpers
end


describe StompHandler do

  # Actually these are the real connection params, but we are going to stub, so
  # hopefully it doesn't matter.
  let(:stomp_hash) do
    { hosts: [{ login:    'guest',
                 passcode: 'guest',
                 host:     '10.0.0.150',
                 port:     61613,
                 ssl:      false }],
       reliable: false }
  end

  let(:client) { double( Stomp::Client ).as_null_object }

  let(:handler) do
    sh = StompHandler.new(stomp_hash, client)
    
    # Attempt to duplicate anything in Stomp::Client that we might need.
    # This does the opposite of making me happy -- it's hella fragile, and
    # we're dealing with implementation details, in code we don't even
    # maintain! 
    # But. I don't know of another way to do this. And we only do it here, in
    # the test for StompHandler. Everything else can mock StompHandler or use
    # StompHandlerNull.
    conn = double("connection frame").as_null_object

    allow(client).to receive(:connection_frame).and_return(conn)
    allow(client).to receive_message_chain("connection_frame.headers").
       and_return({"session" => "123"})

    sh
  end

  let(:msg1) do
    stomp_message('application/text', 'verb:Foo', client.calc_reply_id)
  end

  let(:msg2) do
    stomp_message('application/text', 'verb:Bar', client.calc_reply_id)
  end


  describe "StompHandler.with_timeout" do

    it "should hang for the given timeout period" do
      start = Time.now
      StompHandler.with_timeout(2) do |r|
      end
      stop = Time.now

      expect(stop - start).to be_within(0.5).of(2)
    end

    it "should drop out of the block when given the signal" do
      start = Time.now
      StompHandler.with_timeout(2) do |r|
        r.signal
      end
      stop = Time.now

      expect(stop - start).to be < 0.5
    end

  end
  ##


  describe "#initialize" do

    it "takes an initialization hash" do
      expect{ StompHandler.new(foo: 'bar') }.not_to raise_exception
    end

  end
  ##


  describe "#stomp_connect" do

    it "raises ConnectionError if it cannot connect to the STOMP server" do
      hash = stomp_hash.merge( hosts: {passcode:'flurb'} )
      sh = StompHandler.new(hash)

      expect{sh.stomp_connect}.to raise_exception NebulousStomp::ConnectionError
    end

    it "returns self" do
      expect(handler.stomp_connect).to eq handler
    end

    it "sets client to an instance of STOMP::Client" do
      # Weeeeelllll -- actually... it isn't. It's the double.
      handler.stomp_connect
      expect(handler.client).to eq client
    end

    it "connects to the STOMP server" do
      # in passing we test #connected? -- there doesn't seem to be a way to (or
      # a point in) test(ing) it seperately.
      handler.stomp_connect
      expect( handler ).to be_connected
    end

    it 'doesn''t freak out if Nebulous is not "on"' do
      sh = StompHandler.new({})
      expect{ sh.stomp_connect }.not_to raise_exception
      expect( sh.stomp_connect ).to eq sh
    end

  end
  ##

  
  describe '#nebulous_on?' do

    it 'should be true if there is anything in the stomp hash' do
      sh = StompHandler.new(foo: 'bar')
      expect( sh.nebulous_on? ).to be_truthy
    end

    it 'should be false if the stomp hash is nil' do
      sh = StompHandler.new(nil)
      expect( sh.nebulous_on? ).to be_falsy
    end

  end
  ##


  describe "#stomp_disconnect" do
    it "disconnects!" do
      handler.stomp_connect
      handler.stomp_disconnect

      expect( handler ).not_to be_connected
    end

    it 'doesn''t freak out if Nebulous is not "on"' do
      sh = StompHandler.new({}).stomp_connect
      expect{ sh.stomp_disconnect }.not_to raise_exception
      expect( sh.stomp_disconnect ).to eq sh
    end

  end
  ##


  describe "#calc_reply_id" do

    it "raises an error if the client is not connected" do
      handler.stomp_disconnect

      expect{ handler.calc_reply_id }.
        to raise_exception NebulousStomp::ConnectionError

    end

    it "returns a unique string" do
      # I can't actually check that the string is unique, so this is kinda weak
      handler.stomp_connect
      expect( handler.calc_reply_id ).to respond_to :upcase
      expect( handler.calc_reply_id.size ).to be > 12
    end

    it 'doesn''t freak out if Nebulous is not "on"' do
      sh = StompHandler.new({}).stomp_connect
      expect{ sh.calc_reply_id }.not_to raise_exception
      expect( sh.calc_reply_id ).to eq nil
    end

  end
  ##


  describe "send_message" do
    # We're kind of navel gazing here because send_message is just one line: a
    # call to client.publish. Still, call it a warming up exercise....
    
    let(:mess) { NebulousStomp::Message.new(verb: 'foo', params: nil, desc: nil) }

    before do
      handler.stomp_connect
    end

    it "accepts a queue name and a Message" do
      expect{ handler.send_message        }.to raise_exception ArgumentError
      expect{ handler.send_message('foo') }.to raise_exception ArgumentError
      expect{ handler.send_message(1,2,3) }.to raise_exception ArgumentError
      expect{ handler.send_message('foo', 12) }.
        to raise_exception NebulousStomp::NebulousError

      expect{ handler.send_message('foo', mess) }.not_to raise_exception
    end

    it "returns the message" do
      expect( handler.send_message('foo', mess) ).to eq mess
    end

    it "tries to publish the message" do
      expect(client).to receive(:publish)
      handler.send_message('foo', mess)
    end

    it "tries to reconnect if the client is not connected" do
      handler.stomp_disconnect
      expect(client).to receive(:publish)

      handler.send_message('foo', mess)
      expect{ handler.send_message('foo', mess) }.not_to raise_exception
    end

    it 'doesn''t freak out if Nebulous is not "on"' do
      sh = StompHandler.new({}).stomp_connect
      expect{ sh.send_message('foo', mess) }.not_to raise_exception
      expect( sh.send_message('foo', mess) ).to eq nil
    end


  end
  ##


  describe "#listen" do

    def run_listen(secs)
      got = nil

      handler.listen('/queue/foo') do |m|
        got = m
      end
      sleep secs

      got
    end


    before do
      handler.stomp_connect
    end

    it "tries to reconnect if the client is not connected" do
      handler.stomp_disconnect
      expect(client).to receive(:publish)
      expect{ handler.listen('foo') }.not_to raise_exception
    end

    it "yields a Message if it gets a response on the given queue" do
      allow(client).to receive(:subscribe).and_yield(msg1)
      gotMessage = run_listen(1)

      expect(gotMessage).not_to be_nil
      expect(gotMessage).to be_a_kind_of NebulousStomp::Message
      expect( gotMessage.verb ).to eq 'Foo'
    end

    it "continues blocking after receiving a message" do
      # If it's still blocking, it should receive a second message
      allow(client).to receive(:subscribe).
        and_yield(msg1).
        and_yield(msg2)

      gotMessage = run_listen(2)

      expect(gotMessage).not_to be_nil
      expect(gotMessage).to be_a_kind_of NebulousStomp::Message
      expect( gotMessage.verb ).to eq 'Bar'
    end

    it 'doesn''t freak out if Nebulous is not "on"' do
      sh = StompHandler.new({}).stomp_connect
      expect{ sh.listen('/queue/x') }.not_to raise_exception
      expect{|y| sh.listen('/queue/x', &y) }.not_to yield_control
    end


  end
  ##


  describe "listen_with_timeout" do

    def run_listen_with_timeout(secs)
      got = nil
      handler.listen_with_timeout('/queue/foo', secs) do |m|
        got = m
      end

      got
    end

    before do
      handler.stomp_connect
    end

    it "tries to reconnect if the client is not connected" do
      handler.stomp_disconnect

      expect(client).to receive(:publish)
      expect{ handler.listen_with_timeout('foo', 1) }.
        to raise_exception NebulousTimeout #as opposed to something nastier

    end

    it "yields a Message if it gets a response on the given queue" do
      allow(client).to receive(:subscribe).and_yield(msg1)

      start = Time.now
      gotMessage = run_listen_with_timeout(2)
      stop = Time.now

      expect( gotMessage ).not_to be_nil
      expect( gotMessage ).to be_a_kind_of NebulousStomp::Message
      expect( gotMessage.verb ).to eq 'Foo'
      expect(stop - start).to be < 0.5
    end

    it "stops after the first message" do
      # The opposite of listen. We yield twice but expect the *first* message.
      allow(client).to receive(:subscribe).
        and_yield(msg1).
        and_yield(msg2)

      gotMessage = run_listen_with_timeout(2)

      expect( gotMessage ).not_to be_nil
      expect( gotMessage ).to be_a_kind_of NebulousStomp::Message
      expect( gotMessage.verb ).to eq 'Foo'
    end

    it "stops after a timeout" do
      start = Time.now
      run_listen_with_timeout(2) rescue nil #probably raises NebulousTimeout
      stop = Time.now

      expect(stop - start).to be_within(0.5).of(2)
    end

    it "raises NebulousTimeout after a timeout" do
      expect{ run_listen_with_timeout(1) }.to raise_exception NebulousTimeout
    end

    it 'doesn''t freak out if Nebulous is not "on"'do
      sh = StompHandler.new({}).stomp_connect
      expect{ sh.listen_with_timeout('/queue/x', 1) }.not_to raise_exception
      expect{|y| sh.listen_with_timeout('/queue/x', 1, &y) }.
        not_to yield_control

    end


  end
  ##


end 

