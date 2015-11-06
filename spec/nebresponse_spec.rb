require 'spec_helper'
require 'nebulous/nebresponse'

include Nebulous


describe NebResponse do

  before do
    @datH = { "verb"        =>  " plink",
              "parameters"  =>  ["one", "two"],
              "description" => "test " }

    @datS = @datH.reduce([]) {|m,(k,v)| m << "#{k}:#{v}" }.join("\n")

  end


  describe "#initialize" do

    context "when it is passed a JSON string" do
      it "works" do

        x = @datH.merge( {"headers" => "headers", "body" => "body"} )

        expect{ NebResponse.new(x.to_json) }.not_to raise_exception

        y = NebResponse.new(x.to_json)
        expect( y.headers     ).to eq x["headers"]
        expect( y.body        ).to eq x["body"]
        expect( y.verb        ).to eq x["verb"]
        expect( y.parameters  ).to eq x["parameters"]
        expect( y.description ).to eq x["description"]

      end
    end

    context "when it is passed a STOMP message" do
      before do
        @mess = Stomp::Message.new('')
      end

      it "works with a JSON body" do
        @mess.headers = {"content-type" => "JSON"}
        @mess.body    = @datH.to_json

        expect{ NebResponse.new(@mess) }.not_to raise_exception

        z = NebResponse.new(@mess)
        expect( z.headers     ).to eq @mess.headers
        expect( z.body        ).to eq @mess.body
        expect( z.verb        ).to eq @datH["verb"]
        expect( z.parameters  ).to eq @datH["parameters"]
        expect( z.description ).to eq @datH["description"]
      end

      it "works with a text body" do
        @mess.headers = {"content-type" => 'text'}
        @mess.body    = @datS

        expect{ NebResponse.new(@mess) }.not_to raise_exception

        z = NebResponse.new(@mess)
        expect( z.headers     ).to eq @mess.headers
        expect( z.body        ).to eq @mess.body
        expect( z.verb        ).to eq @datH["verb"].strip
        expect( z.parameters  ).to eq @datH["parameters"].to_s.strip
        expect( z.description ).to eq @datH["description"].strip
      end

      it "doesn't set @description etc unles it finds a verb" do
        @mess.headers = {"content-type" => 'text'}
        @mess.body    = "parameters:one\ndescription:two"

        expect{ NebResponse.new(@mess) }.not_to raise_exception

        z = NebResponse.new(@mess)
        expect( z.verb        ).to eq nil
        expect( z.parameters  ).to eq nil
        expect( z.description ).to eq nil
      end

    end


  end # of #initialize


  describe "#body_to_h" do

    context "if the body is in JSON" do
      it "returns a hash" do

        x = {}
        x["body"] = @datH.to_json
        x["content-type"] = "JSON"

        nr = NebResponse.new(x.to_json)
        expect( nr.body_to_h ).to eq @datH

      end
    end

    context "If the body is not in JSON" do
      it "returns nil" do

        x = {}
        x["body"] = @datS
        x["content-type"] = "text"

        nr = NebResponse.new(x.to_json)
        expect( nr.body_to_h ).to be_nil

      end
    end

    context "If the body is nil(!)" do
      it "returns nil" do
        x = {}
        x["body"] = nil
        x["content-type"] = "JSON"

        nr = NebResponse.new(x.to_json)

        expect{ nr.body_to_h }.to_not raise_exception
        expect( nr.body_to_h ).to be_nil
      end
    end


  end # of #body_to_h


  describe "#to_cache" do

    it "returns a JSON view of the response" do

      x = @datH
      x["body"] = @datH.to_json
      x["headers"] = "content-type:JSON"

      nr = NebResponse.new(x.to_json)
      ans = JSON.parse(nr.to_cache)

      expect( ans ).to include(x)
      expect( ans ).to include(@datH)

    end


  end # of #to_cache


end # of NebResponse

