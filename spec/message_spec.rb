require 'stomp'

require 'spec_helper'
require 'nebulous/message'

require_relative 'helpers'

require 'pry'

include Nebulous


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


  let(:msg_pts) do
    x = Message.from_parts('Daphne', 'Fred', 'Velma', 'Shaggy', 'Scooby')
    x.reply_id = 42
    x
  end

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


  describe 'Message.from_parts' do

    it 'returns a Message object' do
      expect( msg_pts ).to be_a_kind_of(Message)
    end

    it 'sets protocol attributes if it can, raises hell otherwise' do
      expect{ Message.from_parts }.to raise_exception ArgumentError

      expect{ Message.from_parts(nil, nil, nil, nil, nil) }.
        to raise_exception ArgumentError

      expect( msg_pts.reply_to    ).to eq 'Daphne'
      expect( msg_pts.in_reply_to ).to eq 'Fred'
      expect( msg_pts.verb        ).to eq 'Velma'
      expect( msg_pts.params      ).to eq 'Shaggy'
      expect( msg_pts.desc        ).to eq 'Scooby'
    end

    it "assumes a content type of JSON" do
      expect( msg_pts.content_type ).to match(/json$/i)
    end

  end
  ##


  describe 'Message.in_reply_to' do

    let(:msg) do 
      Message.in_reply_to(msg_pts, 'Buffy', 'Willow', 'Xander', 'Ripper')
    end


    it 'requires another Message object and a verb' do
      expect{ Message.in_reply_to('foo') }.to raise_exception ArgumentError

      expect{ Message.in_reply_to('foo', 'bar') }.
        to raise_exception ArgumentError

      expect{ Message.in_reply_to(msg_pts, 'bar') }.not_to raise_exception
    end

    it 'returns a fresh Message object' do
      expect( msg ).to be_a_kind_of(Message)
      expect( msg ).not_to eq(msg_pts)
    end

    it 'sets Protocol attributes' do
      expect( msg.verb     ).to eq 'Buffy'
      expect( msg.params   ).to eq 'Willow'
      expect( msg.desc     ).to eq 'Xander'
      expect( msg.reply_to ).to eq 'Ripper'

      # NB the reply_id (message ID) not the reply_to (the queue)
      expect( msg.in_reply_to ).to eq 42 
    end

    it 'sets the content type from the source message' do
      expect( msg.content_type ).to eq msg_pts.content_type
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
      expect(msg_pts.parameters).to eq msg_pts.params
    end
  end
  ##


  describe '#description' do
    it 'returns the same as @desc' do
      expect(msg_pts.description).to eq msg_pts.desc
    end
  end
  ##


  describe '#content_is_json?' do

    it 'returns true if the body is supposed to be JSON' do
      expect( msg_pts.content_is_json? ).to be true
    end

    it 'returns false unless the body is supposed to be JSON' do
      smess = stomp_message('application/text', 'foo') 
      mess  = Message.from_stomp(smess) 
      expect( mess.content_is_json? ).to be false

      mess = Message.from_cache( {contentType: 'dunno'}.to_json )
      expect( mess.content_is_json? ).to be false

      mess = Message.from_cache( {horse: 'badger'}.to_json )
      expect( mess.content_is_json? ).to be false
    end

  end
  ##


  describe '#to_cache' do

    it 'returns the message as a hash' do
      hash = msg_pts.to_cache

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
      expect(mess.to_cache).to eq symbolise(json_hash)
    end
      

  end
  ##


  describe '#protocol_json' do
    it "returns the Protocol as a JSON string" do
      hash = JSON.parse( msg_pts.protocol_json, symbolize_names: true )

      expect( hash ).to include(verb: 'Velma')

      expect( hash ).to include(params: 'Shaggy').
                     or include(parameters: 'Shaggy')

      expect( hash ).to include(desc: 'Scooby').
                     or include(description: 'Scooby')

    end
  end
  ##


  describe "#body_to_h" do

    context "if the body is in JSON" do

      it "returns a hash"  do
        x = {}
        x[:stompHeaders] = {}
        x[:stompBody]    = @datH.to_json # JSONd twice?
        x[:contentType]  = "JSON"

        nr = Message.from_cache(x.to_json)
        expect( nr.body_to_h ).to eq @datH
      end

    end

    context "If the body is not in JSON" do
      it "returns nil" do

        x = {}
        x["body"] = @datS
        x["content-type"] = "text"

        nr = Message.from_cache(x.to_json)
        expect( nr.body_to_h ).to be_nil

      end
    end

    context "If the body is nil(!)" do
      it "returns nil" do
        x = {}
        x["body"] = nil
        x["content-type"] = "JSON"

        nr = Message.from_cache(x.to_json)

        expect{ nr.body_to_h }.to_not raise_exception
        expect( nr.body_to_h ).to be_nil
      end
    end

  end
  ##


  describe '#headers_for_stomp' do

    it 'always returns a Hash' do
      expect( msg_pts.headers_for_stomp   ).to be_a_kind_of Hash
      expect( msg_stomp.headers_for_stomp ).to be_a_kind_of Hash
      expect( msg_cache.headers_for_stomp ).to be_a_kind_of Hash
    end

    it "returns the custom headers for the Stomp gem" do
      hdrs = msg_pts.headers_for_stomp
      expect( hdrs ).to include("content-type"    => 'application/json')
      expect( hdrs ).to include("neb-reply-id"    => 42)
      expect( hdrs ).to include("neb-reply-to"    => 'Daphne')
      expect( hdrs ).to include("neb-in-reply-to" => 'Fred')

      hdrs = msg_stomp.headers_for_stomp
      expect( hdrs ).to include("content-type" => 'application/text')
      expect( hdrs ).to include("neb-reply-id" => nil)
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


  describe '#respond_success' do

    it "raises an error if we have no @reply_to" do
      expect{ msg_stomp.respond_success }.to raise_exception NebulousError
    end

    it "returns the queue to respond on" do
      q,_ = msg_cache.respond_success
      expect( q ).to eq '/queue/thing'
    end

    it "returns a new message that has the success verb" do
      _,m = msg_cache.respond_success
      expect( m ).to be_a_kind_of Message
      expect( m.verb ).to eq 'success'
    end

  end
  ##


  describe '#respond_error' do
    let(:err) { NebulousError.new("test error") }

    it "raises an error if we have no @reply_to" do
      expect{ msg_stomp.respond_error('foo') }.to raise_exception NebulousError
    end

    it "requires an error parameter" do
      expect{ msg_cache.respond_error() }.to raise_exception ArgumentError
      expect{ msg_cache.respond_error('foo') }.not_to raise_exception
    end

    it "accepts an exception object" do
      expect{ msg_cache.respond_error(err) }.not_to raise_exception
    end

    it "accepts an optional error field" do
      expect{ msg_cache.respond_error('foo', :bar) }.not_to raise_exception
    end

    it "returns the queue to respond on" do
      q,_ = msg_cache.respond_error('foo')
      expect( q ).to eq '/queue/thing'

      q,_ = msg_cache.respond_error(err, :foo)
      expect( q ).to eq '/queue/thing'
    end

    it "returns a new message with the failure verb and details" do
      _,m = msg_cache.respond_error('foo')
      expect( m ).to be_a_kind_of Message
      expect( m.verb ).to eq 'error'
      expect( m.params ).to eq []
      expect( m.desc ).to eq 'foo'

      _,m = msg_cache.respond_error(err, :foo)
      expect( m ).to be_a_kind_of Message
      expect( m.verb ).to eq 'error'
      expect( m.params ).to eq "foo"
      expect( m.desc ).to eq err.message
    end

  end
  ##

end

