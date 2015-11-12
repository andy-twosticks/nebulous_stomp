require 'spec_helper'
require 'helpers'
require 'nebulous/nebresponse'

require 'pry' #bamf

include Nebulous


RSpec.configure do |c|
  c.include Helpers
end


describe NebResponse do

  before do
    @datH = { "verb"   =>  " plink",
              "params" =>  ["one", "two"],
              "desc"   => "test " }

    @datS = @datH.reduce([]) {|m,(k,v)| m << "#{k}:#{v}" }.join("\n")
  end


  describe "#initialize" do

    context "when it is passed a JSON string" do
      it "works" do

        x = @datH.merge( { "stompHeaders" => {headers: true}, 
                           "stompBody"    => "body" } )

        expect{ NebResponse.from_cache(x.to_json) }.not_to raise_exception

        y = NebResponse.from_cache(x.to_json)

        expect( y.headers     ).to eq x["stompHeaders"]
        expect( y.body        ).to eq x["stompBody"]
        expect( y.verb        ).to eq x["verb"]
        expect( y.parameters  ).to eq x["params"]
        expect( y.description ).to eq x["desc"]

      end
    end

    context "when it is passed a STOMP message" do
      before do
        @mess = Stomp::Message.new('')
      end

      it "works with a JSON body" do
        mess = stomp_message('JSON', @datH.to_json)

        expect{ NebResponse.from_stomp(mess) }.not_to raise_exception

        z = NebResponse.from_stomp(mess)
        expect( z.headers     ).to eq mess.headers
        expect( z.body        ).to eq mess.body
        expect( z.verb        ).to eq @datH["verb"]
        expect( z.parameters  ).to eq @datH["params"]
        expect( z.description ).to eq @datH["desc"]
      end

      it "works with a text body" do
        mess = stomp_message('text', @datS)

        expect{ NebResponse.from_stomp(mess) }.not_to raise_exception

        z = NebResponse.from_stomp(mess)
        expect( z.headers     ).to eq mess.headers
        expect( z.body        ).to eq mess.body
        expect( z.verb        ).to eq @datH["verb"].strip
        expect( z.parameters  ).to eq @datH["params"].to_s.strip
        expect( z.description ).to eq @datH["desc"].strip
      end

      it "doesn't set @description etc unles it finds a verb" do
        mess = stomp_message( 'text',
                              "parameters:one\ndescription:two" )

        expect{ NebResponse.from_stomp(mess) }.not_to raise_exception

        z = NebResponse.from_stomp(mess)
        expect( z.verb        ).to eq nil
        expect( z.parameters  ).to eq nil
        expect( z.description ).to eq nil
      end

    end


  end # of #initialize
  ##


  describe "#body_to_h" do

    context "if the body is in JSON" do

      it "returns a hash"  do
        x = {}
        x[:stompHeaders] = {}
        x[:stompBody]    = @datH.to_json # JSONd twice? 
        x[:contentType]  = "JSON"

        nr = NebResponse.from_cache(x.to_json)
        expect( nr.body_to_h ).to eq @datH
      end

    end

    context "If the body is not in JSON" do
      it "returns nil" do

        x = {}
        x["body"] = @datS
        x["content-type"] = "text"

        nr = NebResponse.from_cache(x.to_json)
        expect( nr.body_to_h ).to be_nil

      end
    end

    context "If the body is nil(!)" do
      it "returns nil" do
        x = {}
        x["body"] = nil
        x["content-type"] = "JSON"

        nr = NebResponse.from_cache(x.to_json)

        expect{ nr.body_to_h }.to_not raise_exception
        expect( nr.body_to_h ).to be_nil
      end
    end


  end # of #body_to_h


  describe "#to_cache" do

    it "returns a JSON view of the response" do

      x = @datH
      x["stompBody"]    = @datH.to_json
      x["stompHeaders"] = "content-type:JSON"

      nr = NebResponse.from_cache(x.to_json)
      ans = JSON.parse(nr.to_cache)

      expect( ans ).to include(x)
      expect( ans ).to include(@datH)

    end


  end # of #to_cache


end # of NebResponse

