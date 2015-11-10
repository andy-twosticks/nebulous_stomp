require 'spec_helper'

require 'stomp'

require 'nebulous/message'

include Nebulous


describe Message do


  def stomp_message(contentType, body, inReplyTo=nil)

    headers = { 'destination'  => '/queue/foo',
                'message-id'   => '999',
                'content-type' => contentType }

    headers['neb-in-reply-to'] = inReplyTo if inReplyTo

    mess = ['MESSAGE'] \
           + headers.map{|k,v| "#{k}:#{v}" } \
           << '' \
           << body

    Stomp::Message.new( mess.join("\n") + "\0" )
  end
  ##


  describe 'Message.from_parts' do
    before do
      @mess = Message.from_parts('Daphne', 'Fred', 'Velma', 'Shaggy', 'Scooby')
    end

    it 'returns a Message object' do
      expect( @mess ).to be_a_kind_of(Message)
    end

    it 'sets protocol attributes if it can, raises hell otherwise' do
      expect{ Message.from_parts }.to raise_exception ArgumentError

      expect{ Message.from_parts(nil, nil, nil, nil, nil) }.
        to raise_exception ArgumentError

      expect( @mess.reply_to    ).to eq 'Daphne'
      expect( @mess.in_reply_to ).to eq 'Fred'
      expect( @mess.verb        ).to eq 'Velma'
      expect( @mess.params      ).to eq 'Shaggy'
      expect( @mess.desc        ).to eq 'Scooby'
    end

    it "assumes a content type of JSON" do
      expect( @mess.content_type ).to match(/json$/i)
    end

  end
  ##


  describe 'Message.in_reply_to' do

    before do
      @from = Message.from_parts('Daphne', 'Fred', 'Velma', 'Shaggy', 'Scooby')
      @from.reply_id = 42
      @msg  = Message.in_reply_to(@from, 'Buffy', 'Willow', 'Xander', 'Ripper')
    end

    it 'requires another Message object and a verb' do
      expect{ Message.in_reply_to('foo') }.to raise_exception ArgumentError

      expect{ Message.in_reply_to('foo', 'bar') }.
        to raise_exception ArgumentError

      expect{ Message.in_reply_to(@from, 'bar') }.not_to raise_exception
    end

    it 'returns a fresh Message object' do
      expect( @msg ).to be_a_kind_of(Message)
      expect( @msg ).not_to eq(@from)
    end

    it 'sets Protocol attributes' do
      expect( @msg.verb        ).to eq 'Buffy'
      expect( @msg.params      ).to eq 'Willow'
      expect( @msg.desc        ).to eq 'Xander'
      expect( @msg.reply_to    ).to eq 'Ripper'

      # NB the reply_id (message ID) not the reply_to (the queue)
      expect( @msg.in_reply_to ).to eq 42 
    end

    it 'sets the content type from the source message' do
      expect( @msg.content_type ).to eq @from.content_type
    end

  end
  ##


  describe 'Message.from_stomp' do
    before do
      @smess = stomp_message('application/text', 'foo')
      @mess = Message.from_stomp(@smess)
    end

    it 'requires a Stomp::Message' do
      expect{ Message.from_stomp         }.to raise_exception ArgumentError
      expect{ Message.from_stomp('foo')  }.to raise_exception ArgumentError
      expect{ Message.from_stomp(@smess) }.not_to raise_exception
    end

    it 'returns a Message object' do
      expect( @mess ).to be_a_kind_of Message
    end

    it 'sets stomp header attribute' do
      expect( @mess.stomp_message ).to eq @smess
    end

    it 'still works if there are no Protocol attributes to set' do
      expect( @mess.verb        ).to eq nil
      expect( @mess.params      ).to eq nil
      expect( @mess.desc        ).to eq nil
      expect( @mess.reply_to    ).to eq nil
      expect( @mess.in_reply_to ).to eq nil
    end

    it 'sets Protocol attributes if it can' do
      body = {verb: 'Dougal', params: 'Florence', desc: 'Ermintrude'}
      mess = stomp_message('application/json', body.to_json, '23')
      msg2 = Message.from_stomp(mess)
      expect( msg2.verb        ).to eq 'Dougal'
      expect( msg2.params      ).to eq 'Florence'
      expect( msg2.desc        ).to eq 'Ermintrude'
      expect( msg2.in_reply_to ).to eq '23'
    end

  end
  ##


  describe 'Message.from_cache' do

    before do
      @smess = stomp_message('application/text', 'foo')

      # Let's have completely different settings to the message. Our Message
      # should follow these, not those.
      @json = { stompMessage: @smess,
                verb:         'tom',
                params:       'dick',
                desc:         'harry',
                replyTo:      '/queue/thing',
                replyId:      '1234',
                inReplyTo:    '4321',
                contentType:  'application/json' }.to_json

      @mess = Message.from_cache(@json)
    end

    it 'requires some json in the right format' do
      expect{ Message.from_cache              }.to raise_exception ArgumentError
      expect{ Message.from_cache('foo')       }.to raise_exception ArgumentError
      expect{ Message.from_cache({})          }.to raise_exception ArgumentError
      expect{ Message.from_cache({foo:'bar'}) }.to raise_exception ArgumentError
      expect{ Message.from_cache(@json) }.not_to raise_exception
    end

    it 'sets stomp header attribute' do
      expect( @mess.stomp_message ).to eq @smess.to_json
    end

    it 'sets Protocol attributes if it can, fails nice otherwise'

    it 'returns a Message object'

  end


=begin
  parameters
  description
  content_is_json?
  to_cache
  fill_from_message
  stomp_header
  stomp_body
  respond_success
  respond_error
  protocol_json
=end




end

