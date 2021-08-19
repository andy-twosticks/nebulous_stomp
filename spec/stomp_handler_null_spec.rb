require "time"
require "nebulous_stomp/stomp_handler_null"
require "nebulous_stomp/stomp_handler"

include NebulousStomp


describe StompHandlerNull do

  def run_listen(secs)
    got = []

    handler.listen('/queue/foo') do |m|
      got << m
    end
    sleep secs

    got
  end

  def run_listen_with_timeout(secs)
    got = []
    handler.listen_with_timeout('/queue/foo', secs) do |m|
      got << m
    end

    got
  end

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

  let(:fakestomp) { double("fakestomp") }

  let(:handler) do
    allow(Stomp::Client).to receive(:new).and_return(fakestomp)

    # Normally you wouldn't bother passing a stomp connection hash to StompHandlerNull, but we need
    # to test that we don't connect to Stomp, so we need to give the ("presumably") underlying
    # StompHandler class something to work with.
    StompHandlerNull.new(stomp_hash)
  end

  let(:msg1) do
    stomp_message("application/text", "verb:Foo", client.calc_reply_id)
  end

  let(:msg2) do
    stomp_message("application/text", "verb:Bar", client.calc_reply_id)
  end


  describe "#initialize" do

    it "takes an initialization hash" do
      expect{ StompHandlerNull.new(foo: 'bar') }.not_to raise_exception
    end

  end # of #initialize
  

  describe '#insert_fake' do

    it "sets the message to send" do
      handler.insert_fake( Message.new(verb: 'foo', params: 'bar', desc: 'baz') )
      expect( handler.fake_messages            ).to be_a_kind_of Array
      expect( handler.fake_messages.first      ).to be_a_kind_of NebulousStomp::Message
      expect( handler.fake_messages.first.verb ).to eq 'foo'
    end

  end # of #insert_fake
  

  describe "#connected?" do

    it "returns false if fake_message was not called" do
      expect( handler.connected? ).to be_falsey
    end

    it "returns true if fake_message was called" do
      handler.insert_fake( Message.new(verb: 'one', params: 'two', desc: 'three') )
      expect( handler.connected? ).to be_truthy
    end

    it "does not call Stomp" do
      # More generally if we call anything on our Stomp::Client.new fake, we'll get an error
      expect( fakestomp ).not_to receive(:open?)
      handler.connected?
    end

  end # of #connected?


  describe "#stomp_connect" do

    it "returns self" do
      expect(handler.stomp_connect).to eq handler
    end

    it "does not call Stomp" do
      # More generally if we call anything on our Stomp::Client.new fake, we'll get an error
      expect( fakestomp ).not_to receive(:connection_frame)
      handler.stomp_connect
    end

  end # of #stomp_connect


  describe "#calc_reply_id" do

    it "returns a 'unique' string" do
      handler.stomp_connect
      expect( handler.calc_reply_id ).to respond_to :upcase
      expect( handler.calc_reply_id.size ).to be > 12
    end

    it "does not call Stomp" do
      # More generally if we call anything on our Stomp::Client.new fake, we'll get an error
      expect( fakestomp ).not_to receive(:connection_frame)
      handler.calc_reply_id
    end

  end # of #calc_reply_id


  describe "#send_message" do
    let(:mess) { NebulousStomp::Message.new(verb: 'foo') }

    it "accepts a queue name and a Message" do
      expect{ handler.send_message('foo', mess) }.not_to raise_exception
    end

    it "returns the message" do
      expect( handler.send_message('foo', mess) ).to eq mess
    end

    it "does not call Stomp" do
      # More generally if we call anything on our Stomp::Client.new fake, we'll get an error
      expect( fakestomp ).not_to receive(:publish)
      handler.send_message('foo', mess)
    end

  end # of #send_message


  describe "#listen" do

    it "yields each Message" do
      handler.insert_fake( Message.new(verb: 'foo', params: 'bar', desc: 'baz') )
      handler.insert_fake( Message.new(verb: 'one', params: 'two', desc: 'three') )
      messages = run_listen(1)

      expect(messages.first).not_to be_nil
      expect(messages.first).to be_a_kind_of NebulousStomp::Message
      expect(messages.first.verb).to eq "foo"

      expect(messages.last).not_to be_nil
      expect(messages.last).to be_a_kind_of NebulousStomp::Message
      expect(messages.last.verb).to eq "one"
    end

    it "does not call Stomp" do
      # More generally if we call anything on our Stomp::Client.new fake, we'll get an error
      expect( fakestomp ).not_to receive(:subscribe)

      handler.insert_fake( Message.new(verb: 'foo', params: 'bar', desc: 'baz') )
      handler.insert_fake( Message.new(verb: 'one', params: 'two', desc: 'three') )
      messages = run_listen(1)
    end

  end # of #listen


  describe "listen_with_timeout" do

    context "when there are messages" do
      it "yields each Message" do
        handler.insert_fake( Message.new(verb: 'foo', params: 'bar', desc: 'baz') )
        handler.insert_fake( Message.new(verb: 'one', params: 'two', desc: 'three') )
        messages = run_listen_with_timeout(1)

        expect( messages.first ).not_to be_nil
        expect( messages.first ).to be_a_kind_of NebulousStomp::Message
        expect(messages.first.verb).to eq "foo"

        expect(messages.last).not_to be_nil
        expect(messages.last).to be_a_kind_of NebulousStomp::Message
        expect(messages.last.verb).to eq "one"
      end
    end

    context "when there is no message" do
      it "raises NebulousTimeout" do
        expect{handler.listen_with_timeout('foo', 2)}.
          to raise_exception NebulousStomp::NebulousTimeout

      end
    end

    it "does not call Stomp" do
      # More generally if we call anything on our Stomp::Client.new fake, we'll get an error
      expect( fakestomp ).not_to receive(:subscribe)

      handler.insert_fake( Message.new(verb: 'foo', params: 'bar', desc: 'baz') )
      handler.insert_fake( Message.new(verb: 'one', params: 'two', desc: 'three') )
      messages = run_listen_with_timeout(1)
    end

  end # of #listen_with_timeout


end 

