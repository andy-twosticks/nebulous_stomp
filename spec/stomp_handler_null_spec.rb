require 'time'
require 'nebulous_stomp/stomp_handler_null'

include NebulousStomp


describe StompHandlerNull do

  let(:handler) do
    StompHandlerNull.new
  end

  let(:msg1) do
    stomp_message('application/text', 'verb:Foo', client.calc_reply_id)
  end

  let(:msg2) do
    stomp_message('application/text', 'verb:Bar', client.calc_reply_id)
  end


  describe "#initialize" do

    it "takes an initialization hash" do
      expect{ StompHandlerNull.new(foo: 'bar') }.not_to raise_exception
    end

  end
  ##
  

  describe '#insert_fake' do

    it 'sets the message to send' do
      handler.insert_fake( Message.new(verb: 'foo', params: 'bar', desc: 'baz') )
      expect( handler.fake_messages            ).to be_a_kind_of Array
      expect( handler.fake_messages.first      ).to be_a_kind_of NebulousStomp::Message
      expect( handler.fake_messages.first.verb ).to eq 'foo'
    end

  end
  ##
  

  describe '#connected?' do

    it 'returns false if fake_message was not called' do
      expect( handler.connected? ).to be_falsey
    end

    it 'returns true if fake_message was called' do
      handler.insert_fake( Message.new(verb: 'one', params: 'two', desc: 'three') )
      expect( handler.connected? ).to be_truthy
    end

  end
  ##


  describe "#stomp_connect" do

    it "returns self" do
      expect(handler.stomp_connect).to eq handler
    end

  end
  ##


  describe "#calc_reply_id" do

    it "returns a 'unique' string" do
      handler.stomp_connect
      expect( handler.calc_reply_id ).to respond_to :upcase
      expect( handler.calc_reply_id.size ).to be > 12
    end
  end
  ##


  describe "send_message" do
    let(:mess) { NebulousStomp::Message.new(verb: 'foo') }

    it "accepts a queue name and a Message" do
      expect{ handler.send_message('foo', mess) }.not_to raise_exception
    end

    it "returns the message" do
      expect( handler.send_message('foo', mess) ).to eq mess
    end

  end
  ##


  describe "#listen" do

    def run_listen(secs)
      got = []

      handler.listen('/queue/foo') do |m|
        got << m
      end
      sleep secs

      got
    end


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

  end
  ##


  describe "listen_with_timeout" do

    def run_listen_with_timeout(secs)
      got = []
      handler.listen_with_timeout('/queue/foo', secs) do |m|
        got << m
      end

      got
    end

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

      it 'raises NebulousTimeout' do
        expect{handler.listen_with_timeout('foo', 2)}.
          to raise_exception NebulousStomp::NebulousTimeout

      end

    end

  end
  ##


end 

