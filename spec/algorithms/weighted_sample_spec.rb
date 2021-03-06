require_relative "../spec_helper"

describe Funtestic::Algorithms::WeightedSample do
  it "should return an alternative" do
    experiment = Funtestic::Experiment.find_or_create('link_color', {:name => 'blue', :weight => 100}, {:name => 'red', :weight => 0})
    Funtestic::Algorithms::WeightedSample.choose_alternative(experiment).class.should == Funtestic::Alternative
  end

  it "should always return a heavily weighted option" do
    experiment = Funtestic::Experiment.find_or_create('link_color', {:name => 'blue', :weight => 100}, {:name => 'red', :weight => 0})
    Funtestic::Algorithms::WeightedSample.choose_alternative(experiment).name.should == 'blue'
  end
  
  it "should return one of the results" do
    experiment = Funtestic::Experiment.find_or_create('link_color', {:name => 'blue', :weight => 1}, {:name => 'red', :weight => 1})
    ['red', 'blue'].should include Funtestic::Algorithms::WeightedSample.choose_alternative(experiment).name
  end
end