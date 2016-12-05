require 'stomp'

require 'spec_helper'
require 'nebulous_stomp/message'

require_relative 'helpers'

include NebulousStomp


RSpec.configure do |c|
  c.include Helpers
end



describe Message do

  # the cacheing process can't preserve the symbol-or-text-ness of the
  # headers; we're stuck with that. So for comparison purposes this helper
  # function deep-converts all keys in a hash to symbols.
  def symbolise(hash)

    hash.each_with_object({}) do |(k,v),m| 
      m[k.to_sym] = v.kind_of?(Hash) ? symbolise(v) : v
    end

  end


  let(:new_hash) do
    { replyTo:   'Daphne', 
      inReplyTo: 'Fred', 
      verb:      'Velma', 
      params:    'Shaggy', 
      desc:      'Scooby' }

  end

  let(:msg_new)  { Message.new new_hash }
  let(:msg_new2) { Message.new new_hash.merge(replyId: 42) }

  let(:smess)     { stomp_message('application/text', 'foo') } 
  let(:msg_stomp) { Message.from_stomp(smess) }

  let(:json_hash) do
      b = { verb:   'tom',
            params: 'dick',
            desc:   'harry' }.to_json

      x = Message.from_stomp( stomp_message('application/json', b) )

      { stompHeaders: x.stomp_headers,
        stompBody:    x.stomp_body,
        verb:         'tom',
        params:       'dick',
        desc:         'harry',
        replyTo:      '/queue/thing',
        replyId:      '1234',
        inReplyTo:    '4321',
        contentType:  'application/json' }

  end

  let(:msg_cache) { Message.from_cache( json_hash.to_json ) }


  describe 'Message.new (called directly)' do

    it 'returns a Message object' do
      expect( msg_new ).to be_a_kind_of(Message)
    end

    it 'sets protocol attributes if it can' do
      expect( msg_new.reply_to    ).to eq new_hash[:replyTo]
      expect( msg_new.in_reply_to ).to eq new_hash[:inReplyTo]
      expect( msg_new.verb        ).to eq new_hash[:verb]
      expect( msg_new.params      ).to eq new_hash[:params]
      expect( msg_new.desc        ).to eq new_hash[:desc]
    end

    it 'takes the content type from the input arguments' do
      msg = Message.new( new_hash.merge(contentType: 'foo') )
      expect( msg.content_type ).to eq "foo"
    end

    it "assumes a content type of JSON if one is not given" do
      expect( msg_new.content_type ).to match(/json$/i)
    end

    it "is fine with messages not having a replyTo or a verb" do
      expect{ Message.new(verb: 'thing'              ) }.not_to raise_exception
      expect{ Message.new(replyTo: 'foo', body: 'bar') }.not_to raise_exception
      expect{ Message.new(body: 'bar')                 }.not_to raise_exception
    end

  end
  ##


  describe 'Message.in_reply_to' do

    it "requires a message to reply to and a hash" do
      expect{ Message.in_reply_to()             }.to raise_error ArgumentError
      expect{ Message.in_reply_to("foo")        }.to raise_error ArgumentError
      expect{ Message.in_reply_to(msg_new2)     }.to raise_error ArgumentError
      expect{ Message.in_reply_to(msg_new2, 14) }.to raise_error ArgumentError

      expect{ Message.in_reply_to(msg_new2, body: "foo") }.not_to raise_error
    end

    it "raises ArgumentError if the initial message has no reply_id" do
      expect{ Message.in_reply_to(msg_stomp, verb: 'foo') }.to raise_exception ArgumentError
    end

    it "sets the content type from the initial message" do
      msg = Message.in_reply_to(msg_new2, body: 'foo')
      expect( msg.content_type ).to eq msg_new.content_type
    end

    it "sets the in_reply_to to the initial message reply_id" do
      msg = Message.in_reply_to(msg_new2, body: 'foo')
      expect( msg.in_reply_to ).to eq msg_new2.reply_id
    end

  end
  ##


  describe 'Message.from_stomp' do

    it 'requires a Stomp::Message' do
      expect{ Message.from_stomp        }.to raise_exception ArgumentError
      expect{ Message.from_stomp('foo') }.to raise_exception ArgumentError
      expect{ Message.from_stomp(smess) }.not_to raise_exception
    end

    it 'sets stomp attributes' do
      expect( msg_stomp.stomp_headers ).to include smess.headers
      expect( msg_stomp.stomp_body    ).to eq smess.body
    end

    it 'still works if there are no Protocol attributes to set' do
      expect( msg_stomp.verb        ).to eq nil
      expect( msg_stomp.params      ).to eq nil
      expect( msg_stomp.desc        ).to eq nil
      expect( msg_stomp.reply_to    ).to eq nil
      expect( msg_stomp.in_reply_to ).to eq nil
    end

    it 'sets the content type to whatever the headers say it is' do
      b = { verb:   'tom',
            params: 'dick',
            desc:   'harry' }.to_json

      x = Message.from_stomp( stomp_message('barry', b) )
      expect( x.content_type ).to eq 'barry'
    end

    context "when the message body is text" do

      it 'returns a Message object' do
        expect( msg_stomp ).to be_a_kind_of Message
      end

      it 'sets Protocol attributes if it can' do
        body = {verb: 'Dougal', params: 'Florence', desc: 'Ermintrude'}
        mess = stomp_message('application/json', body.to_json, '23')
        msg  = Message.from_stomp(mess)
        expect( msg.verb        ).to eq 'Dougal'
        expect( msg.params      ).to eq 'Florence'
        expect( msg.desc        ).to eq 'Ermintrude'
        expect( msg.in_reply_to ).to eq '23'
      end

    end


    context "when the message body is JSON" do
      
      let(:msg_stomp_json) do
        m = {verb: 'one', params: 'two', desc: 'three'}.to_json
        x = stomp_message('application/json', m, '19')
        Message.from_stomp(x)
      end

      it 'returns a Message object' do
        expect( msg_stomp_json ).to be_a_kind_of Message
      end

      it 'sets Protocol attributes if it can' do
        expect( msg_stomp_json.verb        ).to eq 'one'
        expect( msg_stomp_json.params      ).to eq 'two'
        expect( msg_stomp_json.desc        ).to eq 'three'
        expect( msg_stomp_json.in_reply_to ).to eq '19'
      end

    end

  end
  ##


  describe 'Message.from_cache' do

    let(:msg2) do
      x = { replyId:      '1234',
            contentType:  'application/json' }.to_json

      Message.from_cache(x)
    end


    it 'requires some json in the right format' do
      expect{ Message.from_cache              }.to raise_exception ArgumentError
      expect{ Message.from_cache('foo')       }.to raise_exception ArgumentError
      expect{ Message.from_cache({})          }.to raise_exception ArgumentError
      expect{ Message.from_cache({foo:'bar'}) }.to raise_exception ArgumentError

      expect{ Message.from_cache(json_hash.to_json) }.not_to raise_exception
    end

    it "copes with some loon passing header and not body or vice versa" do
      # I know because ... I was that soldier.
      
      loony1 = { stompHeader: 'foo' }
      loony2 = { stompBody:   'bar' }

      expect{ Message.from_cache(loony1.to_json) }.not_to raise_exception
      expect{ Message.from_cache(loony2.to_json) }.not_to raise_exception
    end

    it 'still works if there are no Protocol attributes to set' do
      expect( msg2.verb        ).to eq nil
      expect( msg2.params      ).to eq nil
      expect( msg2.desc        ).to eq nil
      expect( msg2.reply_to    ).to eq nil
      expect( msg2.in_reply_to ).to eq nil
    end

    it 'sets Protocol attributes if it can' do 
      expect( msg_cache.verb        ).to eq 'tom'
      expect( msg_cache.params      ).to eq 'dick'
      expect( msg_cache.desc        ).to eq 'harry'
      expect( msg_cache.reply_to    ).to eq '/queue/thing'
      expect( msg_cache.in_reply_to ).to eq '4321'
    end


    context "when the message body is JSON" do
      # msg_cache has a json body

      it 'returns a Message object' do
        expect( msg_cache ).to be_a_kind_of Message
      end

      it 'sets the stomp attributes' do
        expect( msg_cache.stomp_headers ).
          to eq symbolise( json_hash[:stompHeaders] )

        expect( msg_cache.stomp_body    ).to eq json_hash[:stompBody]
      end

      it 'sets the content type' do
        expect( msg_cache.content_type ).to eq json_hash[:contentType]
      end

    end


    context "when the message body is text" do

      let(:msg3_cache) do
          { stompHeaders: msg_stomp.stomp_headers,
            stompBody:    msg_stomp.stomp_body,
            verb:         'alice',
            params:       'karen',
            desc:         'jessica',
            replyTo:      '/queue/thing',
            replyId:      '9876',
            inReplyTo:    '6789',
            contentType:  'application/text' }

      end

      let(:msg3) { Message.from_cache( msg3_cache.to_json ) }


      it 'returns a Message object' do
        expect( msg3 ).to be_a_kind_of Message
      end

      it 'sets the stomp attributes' do
        heads = msg3_cache[:stompHeaders].each_with_object({}) do |(k,v),m|
          m[k.to_sym] = v
        end

        expect( msg3.stomp_headers ).to eq heads
        expect( msg3.stomp_body    ).to eq msg3_cache[:stompBody]
      end

      it 'sets the content type' do
        expect( msg3.content_type ).to eq msg3_cache[:contentType]
      end

    end


  end
  ##


  describe '#parameters' do
    it 'returns the same as @param' do
      expect(msg_new.parameters).to eq msg_new.params
    end
  end
  ##


  describe '#description' do
    it 'returns the same as @desc' do
      expect(msg_new.description).to eq msg_new.desc
    end
  end
  ##


  describe '#content_is_json?' do 

    it "returns true if the content type is JSON" do
      expect( msg_new.content_is_json? ).to be true
    end

    it "returns false if the content type is non-json" do
      msg = Message.new( new_hash.merge(contentType: 'foo') )
      expect( msg.content_type ).to eq "foo"
    end

  end
  ##


  describe '#to_cache' do

    it 'returns the message as a hash' do
      hash = msg_new.to_cache

      expect( hash ).to be_a_kind_of Hash
      expect( hash ).to include( replyTo:   'Daphne',
                                 inReplyTo: 'Fred',
                                 verb:      'Velma',
                                 params:    'Shaggy',
                                 desc:      'Scooby' )

      expect( hash[:contentType] ).to match /json$/i 
    end

    it 'always returns all the keys' do
      expect( msg_stomp.to_cache.keys ).to include(*json_hash.keys)
    end

    it "returns a hash that Message.from_cache doesn''t freak out over" do
      expect{ Message.from_cache(msg_cache.to_cache.to_json) }.
        not_to raise_exception

      mess = Message.from_cache(msg_cache.to_cache.to_json)
      expect(mess.to_cache).to include symbolise(json_hash)
    end
      

  end
  ##


  describe '#protocol_json' do
    it "returns the Protocol as a JSON string" do
      hash = JSON.parse( msg_new.protocol_json, symbolize_names: true )

      expect( hash ).to include(verb: 'Velma')

      expect( hash ).to include(params: 'Shaggy').
                     or include(parameters: 'Shaggy')

      expect( hash ).to include(desc: 'Scooby').
                     or include(description: 'Scooby')

    end
  end
  ##


  describe "#body" do

    it "returns a hash if the stomp body is in JSON" do
      nr = Message.new(stompBody: new_hash.to_json, contentType: "JSON")
      expect( symbolise nr.body ).to eq new_hash
    end

    it "returns a hash if the stomp body is not in JSON" do
      x = new_hash.map{|k,v| "#{k}: #{v}" }.join("\n")

      nr = Message.new(stompBody: x, contentType: "text")
      expect( symbolise nr.body ).to eq new_hash
    end

    it "returns nil if the stomp body is nil(!)" do
      nr = Message.new(stompBody: nil, contentType: "JSON")
      expect{ nr.body }.to_not raise_exception
      expect( nr.body ).to be_nil
    end

    it "returns the body if given and no stomp_body given" do
      nr = Message.new(body: "foo")
      expect( nr.body ).to eq "foo"

      nr = Message.new(stompBody: new_hash.to_json, body: "foo", contentType: "JSON")
      expect( symbolise nr.body ).to eq new_hash
    end

  end
  ##


  describe '#headers_for_stomp' do

    it 'always returns a Hash' do
      expect( msg_new.headers_for_stomp   ).to be_a_kind_of Hash
      expect( msg_stomp.headers_for_stomp ).to be_a_kind_of Hash
      expect( msg_cache.headers_for_stomp ).to be_a_kind_of Hash
    end

    it "returns the custom headers for the Stomp gem" do
      hdrs = msg_new2.headers_for_stomp
      expect( hdrs ).to include("content-type"    => 'application/json')
      expect( hdrs ).to include("neb-reply-id"    => 42)
      expect( hdrs ).to include("neb-reply-to"    => 'Daphne')
      expect( hdrs ).to include("neb-in-reply-to" => 'Fred')

      hdrs = msg_stomp.headers_for_stomp
      expect( hdrs ).to include("content-type" => 'application/text')

      # The point of this test is?
      #expect( hdrs ).to include("neb-reply-id" => nil)
    end

  end
  ##


  describe '#body_for_stomp' do

    it "returns a JSON string for content type JSON" do
      expect{ JSON.parse(msg_cache.body_for_stomp) }.not_to raise_exception

      hash = JSON.parse(msg_cache.body_for_stomp)

      expect( hash ).to include('verb' => 'tom')

      expect( hash ).to include('params' => 'dick').
        or include('parameters' => 'dick')

      expect( hash ).to include('desc' => 'harry').
        or include('description' => 'harry')

    end

    it "returns a header-style string for non-JSON" do
      hash1 = { verb:         'tom',
                params:       'dick',
                desc:         'harry',
                contentType:  'supposedly/boris' }

      msg = Message.from_cache( hash1.to_json )

      expect( msg.body_for_stomp ).to be_a_kind_of String

      hash2 = msg.body_for_stomp.
               split("\n").
               each_with_object({}) {|e,m| k,v = e.split(/:\s*/); m[k] = v }

      expect( hash2 ).to include('verb' => 'tom')

      expect( hash2 ).to include('params' => 'dick').
        or include('parameters' => 'dick')

      expect( hash2 ).to include('desc' => 'harry').
        or include('description' => 'harry')

    end

  end
  ##


  describe '#respond_with_success' do

    it "raises an error if we have no @reply_to" do
      expect{ msg_stomp.respond_with_success }.to raise_exception NebulousError
    end

    it "returns the queue to respond on" do
      q,_ = msg_cache.respond_with_success
      expect( q ).to eq '/queue/thing'
    end

    it "returns a new message that has the success verb" do
      _,m = msg_cache.respond_with_success
      expect( m ).to be_a_kind_of Message
      expect( m.verb ).to eq 'success'
    end

    it 'sets the content type from the source message' do
      _,m = msg_cache.respond_with_success
      expect( m.content_type ).to eq msg_cache.content_type
    end

  end
  ##


  describe '#respond_with_error' do
    let(:err) { NebulousError.new("test error") }

    it "raises an error if we have no @reply_to" do
      expect{ msg_stomp.respond_with_error('foo') }.to raise_exception NebulousError
    end

    it "requires an error parameter" do
      expect{ msg_cache.respond_with_error() }.to raise_exception ArgumentError
      expect{ msg_cache.respond_with_error('foo') }.not_to raise_exception
    end

    it "accepts an exception object" do
      expect{ msg_cache.respond_with_error(err) }.not_to raise_exception
    end

    it "accepts an optional error field" do
      expect{ msg_cache.respond_with_error('foo', :bar) }.not_to raise_exception
    end

    it "returns the queue to respond on" do
      q,_ = msg_cache.respond_with_error('foo')
      expect( q ).to eq '/queue/thing'

      q,_ = msg_cache.respond_with_error(err, :foo)
      expect( q ).to eq '/queue/thing'
    end

    it "returns a new message with the failure verb and details" do
      _,m = msg_cache.respond_with_error('foo')
      expect( m ).to be_a_kind_of Message
      expect( m.verb ).to eq 'error'
      expect( m.params ).to eq []
      expect( m.desc ).to eq 'foo'

      _,m = msg_cache.respond_with_error(err, :foo)
      expect( m ).to be_a_kind_of Message
      expect( m.verb ).to eq 'error'
      expect( m.params ).to eq ["foo"]
      expect( m.desc ).to eq err.message
    end

    it 'sets the content type from the source message' do
      _,m = msg_cache.respond_with_error('foo')
      expect( m.content_type ).to eq msg_cache.content_type
    end

  end
  ##


  describe '#respond_with_protocol' do
     
    it "raises an error if we have no @reply_to" do
      expect{ msg_stomp.respond_with_protocol('foo') }.to raise_exception NebulousError
    end

    it "requires a verb parameter" do
      expect{ msg_cache.respond_with_protocol() }.to raise_exception ArgumentError
      expect{ msg_cache.respond_with_protocol('foo') }.not_to raise_exception
    end

    it "accepts optional 'parameters' and 'description' parameters" do
      expect{ msg_cache.respond_with_protocol('foo', "bar")        }.not_to raise_exception
      expect{ msg_cache.respond_with_protocol('foo', [:a, :b])     }.not_to raise_exception
      expect{ msg_cache.respond_with_protocol('foo', 'bar', 'baz') }.not_to raise_exception
    end

    it "returns a queue to respond on" do
      q,_ = msg_cache.respond_with_protocol('foo')
      expect( q ).to eq '/queue/thing'
    end

    it "returns a new message with the verb, params, and desc" do
      _,m = msg_cache.respond_with_protocol('bleem', 'drort', 'flang')
      expect( m ).to be_a_kind_of Message
      expect( m.verb   ).to eq 'bleem'
      expect( m.params ).to eq 'drort'
      expect( m.desc   ).to eq 'flang'
    end

    it 'sets the content type from the source message' do
      _,m = msg_cache.respond_with_protocol('bleem', 'drort', 'flang')
      expect( m.content_type ).to eq msg_cache.content_type
    end

  end
  ##
  
  
  describe '#respond' do

    let(:msg) { msg_cache.respond("desmond") }
     
    it "raises an error if we have no @reply_to" do
      expect{ msg_stomp.respond('foo') }.to raise_exception NebulousError
    end

    it "requires a message body" do
      expect{ msg_cache.respond() }.to raise_exception ArgumentError
      expect{ msg }.not_to raise_exception
    end

    it "returns a queue to respond on" do
      q,_ = msg
      expect( q ).to eq '/queue/thing'
    end

    it "returns a new message with the given body" do
      _,m = msg
      expect( m ).to be_a_kind_of Message
      expect( m.body ).to eq 'desmond'
    end

    it 'sets the content type from the source message' do
      _,m = msg
      expect( m.content_type ).to eq msg_cache.content_type
    end

  end
  ##
  

end

