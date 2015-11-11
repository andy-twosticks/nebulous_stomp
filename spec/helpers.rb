module Helpers

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
  

end

