require_relative "../spec_helper"

describe Funtestic::Algorithms::Whiplash do

  it "should return an algorithm" do
    experiment = Funtestic::Experiment.find_or_create('link_color', {:name => 'blue', :weight => 1}, {:name => 'red', :weight => 1})
    Funtestic::Algorithms::Whiplash.choose_alternative(experiment).class.should == Funtestic::Alternative
  end

  it "should return one of the results" do
    experiment = Funtestic::Experiment.find_or_create('link_color', {:name => 'blue', :weight => 1}, {:name => 'red', :weight => 1})
    ['red', 'blue'].should include Funtestic::Algorithms::Whiplash.choose_alternative(experiment).name
  end
  
  it "should guess floats" do
    Funtestic::Algorithms::Whiplash.send(:arm_guess, 0, 0).class.should == Float
    Funtestic::Algorithms::Whiplash.send(:arm_guess, 1, 0).class.should == Float
    Funtestic::Algorithms::Whiplash.send(:arm_guess, 2, 1).class.should == Float
    Funtestic::Algorithms::Whiplash.send(:arm_guess, 1000, 5).class.should == Float
    Funtestic::Algorithms::Whiplash.send(:arm_guess, 10, -2).class.should == Float
  end
  
end