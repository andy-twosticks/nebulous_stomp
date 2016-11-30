require 'nebulous_stomp/target'

include NebulousStomp


describe Target do

  let(:hash) do
    { sendQueue:     'sendy',
      receiveQueue:  'receivy',
      messageTimeout: 42 }

  end

  def hash_minus(key)
    hash.delete_if{|k,_| k == key }
  end


  describe "#new" do

    it "accepts a hash" do
      expect{ Target.new      }.to raise_error ArgumentError
      expect{ Target.new 14   }.to raise_error ArgumentError
      expect{ Target.new hash }.not_to raise_error 
    end

    it "raises ArgumentError if the hash does not have :sendQueue" do
      expect{ Target.new(hash_minus :sendQueue) }.to raise_error ArgumentError
    end

    it "raises ArgumentError if the hash does not have :receiveQueue" do
      expect{ Target.new(hash_minus :receiveQueue) }.to raise_error ArgumentError
    end

    it "accepts an optional :messageTimeout" do
      expect{ Target.new hash                        }.not_to raise_error
      expect{ Target.new(hash_minus :messageTimeout) }.not_to raise_error
    end

    it "rejects unknown values in the hash" do
      h = hash.merge(:notavalidthing => 14)
      expect { Target.new h }.to raise_error ArgumentError
    end

  end


  describe "#send_queue" do

    it "returns the send queue" do
      expect( Target.new(hash).send_queue ).to eq hash[:sendQueue]
    end

  end


  describe "#receive_queue" do

    it "returns the receive queue" do
      expect( Target.new(hash).receive_queue ).to eq hash[:receiveQueue]
    end

  end


  describe "#message_timeout" do
     
    it "returns the timeout" do
      expect( Target.new(hash).message_timeout ).to eq hash[:messageTimeout]
    end

    it "defaults the message timeout to nil" do
      expect( Target.new(hash_minus :messageTimeout).message_timeout ).to be_nil
    end
    
  end
  
  
end

