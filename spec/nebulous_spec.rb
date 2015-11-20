require 'spec_helper'

require 'logger'


describe Nebulous do

  after do
    Param.set_logger(nil)
  end


  it 'has a version number' do
    expect(Nebulous::VERSION).not_to be nil
  end
  ##


  describe "Nebulous.set_logger" do

    it "requires an instance of Logger" do
      expect{ Nebulous.set_logger(:foo) }.to raise_exception NebulousError
      expect{ Nebulous.set_logger(nil) }.to raise_exception NebulousError
      expect{ Nebulous.set_logger( Logger.new(STDOUT) ) }.not_to raise_exception
    end

  end
  ##


  describe 'Nebulous.logger' do

    it 'returns the logger as set by Param' do
      l = Logger.new(STDOUT)
      Nebulous.set_logger(l)

      expect( Nebulous.logger ).to eq l
    end

    it 'still works if no-one set the logger' do
      expect{ Nebulous.logger }.not_to raise_exception
      expect( Nebulous.logger ).to be_a_kind_of Logger
    end

  end
  ##
  

=begin
  # BAMF
  Nebulous.ini
  Nebulous.add_target
=end

end


