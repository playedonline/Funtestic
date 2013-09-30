require_relative 'spec_helper'
require 'Funtestic/trial'

describe Funtestic::Trial do
  it "should be initializeable" do
    experiment  = double('experiment')
    alternative = double('alternative', :kind_of? => Funtestic::Alternative)
    trial = Funtestic::Trial.new(:experiment => experiment, :alternative => alternative)
    trial.experiment.should == experiment
    trial.alternative.should == alternative
    trial.goals.should == []
  end

  describe "alternative" do
    it "should use the alternative if specified" do
      alternative = double('alternative', :kind_of? => Funtestic::Alternative)
      trial = Funtestic::Trial.new(:experiment => experiment = double('experiment'), :alternative => alternative)
      trial.should_not_receive(:choose)
      trial.alternative.should == alternative
    end

    it "should populate alternative with a full alternative object after calling choose" do
      experiment = Funtestic::Experiment.new('basket_text', :alternatives => ['basket', 'cart'])
      experiment.save
      trial = Funtestic::Trial.new(:experiment => experiment)
      trial.choose
      trial.alternative.class.should == Funtestic::Alternative
      ['basket', 'cart'].should include(trial.alternative.name)
    end

    it "should populate an alternative when only one option is offerred" do
      experiment = Funtestic::Experiment.new('basket_text', :alternatives => ['basket'])
      experiment.save
      trial = Funtestic::Trial.new(:experiment => experiment)
      trial.choose
      trial.alternative.class.should == Funtestic::Alternative
      trial.alternative.name.should == 'basket'
    end


    it "should choose from the available alternatives" do
      trial = Funtestic::Trial.new(:experiment => experiment = double('experiment'))
      alternative = double('alternative', :kind_of? => Funtestic::Alternative)
      experiment.should_receive(:next_alternative).and_return(alternative)
      alternative.should_receive(:increment_participation)
      experiment.stub(:winner).and_return nil
      trial.choose!

      trial.alternative.should == alternative
    end
  end

  describe "alternative_name" do
    it "should load the alternative when the alternative name is set" do
      experiment = Funtestic::Experiment.new('basket_text', :alternatives => ['basket', "cart"])
      experiment.save

      trial = Funtestic::Trial.new(:experiment => experiment, :alternative => 'basket')
      trial.alternative.name.should == 'basket'
    end
  end
end
