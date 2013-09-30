require_relative "spec_helper"
require 'Funtestic/dashboard/helpers'
require 'bigdecimal'

include Funtestic::DashboardHelpers

describe Funtestic::DashboardHelpers do
  describe 'confidence_level' do
    it 'should handle very small numbers' do
      confidence_level(Complex(2e-18, -0.03)).should eql('No Change')
    end

    it "should consider a z-score of 1.645 < z < 1.96 as 95% confident" do
      confidence_level(1.80).should eql('95% confidence')
    end

  end
end
