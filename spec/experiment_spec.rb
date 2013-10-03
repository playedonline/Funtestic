require_relative "spec_helper"
require 'Funtestic/experiment'
require 'Funtestic/algorithms'
require 'time'

describe Funtestic::Experiment do
  def new_experiment(goals=[])
    Funtestic::Experiment.new('link_color', :alternatives => ['blue', 'red', 'green'], :goals => goals)
  end

  def alternative(color)
    Funtestic::Alternative.new(color, 'link_color')
  end

  let(:experiment) {
    new_experiment
  }

  let(:blue) { alternative("blue") }
  let(:green) { alternative("green") }

  context "with an experiment" do
    let(:experiment) { Funtestic::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"]) }

    it "should have a name" do
      experiment.name.should eql('basket_text')
    end

    it "should have alternatives" do
      experiment.alternatives.length.should be 2
    end

    it "should have alternatives with correct names" do
      experiment.alternatives.collect{|a| a.name}.should == ['Basket', 'Cart']
    end

    it "should save to redis" do
      experiment.save
      Funtestic.redis.exists('basket_text').should be true
    end

    it "should save the start time to redis" do
      experiment_start_time = Time.at(1372167761)
      Time.stub(:now => experiment_start_time)
      experiment.save

      Funtestic::Experiment.find('basket_text').start_time.should == experiment_start_time
    end

    it "should save the selected algorithm to redis" do
      experiment_algorithm = Funtestic::Algorithms::Whiplash
      experiment.algorithm = experiment_algorithm
      experiment.save

      Funtestic::Experiment.find('basket_text').algorithm.should == experiment_algorithm
    end

    it "should handle having a start time stored as a string" do
      experiment_start_time = Time.parse("Sat Mar 03 14:01:03")
      Time.stub(:now => experiment_start_time)
      experiment.save
      Funtestic.redis.hset(:experiment_start_times, "#{experiment.name}:#{experiment.version}", experiment_start_time)

      Funtestic::Experiment.find('basket_text').start_time.should == experiment_start_time
    end

    it "should handle not having a start time" do
      experiment_start_time = Time.parse("Sat Mar 03 14:01:03")
      Time.stub(:now => experiment_start_time)
      experiment.save

      Funtestic.redis.hdel(:experiment_start_times, "#{experiment.name}:#{experiment.version}")

      Funtestic::Experiment.find('basket_text').start_time.should == nil
    end

    it "should not create duplicates when saving multiple times" do
      experiment.save
      experiment.save
      Funtestic.redis.exists('basket_text').should be true
      Funtestic.redis.lrange('basket_text', 0, -1).should eql(['Basket', "Cart"])
    end

    describe 'new record?' do
      it "should know if it hasn't been saved yet" do
        experiment.new_record?.should be_true
      end

      it "should know if it has been saved yet" do
        experiment.save
        experiment.new_record?.should be_false
      end
    end

    describe 'find' do
      it "should return an existing experiment" do
        experiment.save
        experiment = Funtestic::Experiment.find('basket_text')
        experiment.name.should eql('basket_text')
      end

      it "should return an existing experiment" do
        Funtestic::Experiment.find('non_existent_experiment').should be_nil
      end
    end

    describe 'control' do
      it 'should be the first alternative' do
        experiment.save
        experiment.control.name.should eql('Basket')
      end
    end
  end

  describe 'initialization' do
    it "should set the algorithm when passed as an option to the initializer" do
       experiment = Funtestic::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :algorithm =>  Funtestic::Algorithms::Whiplash)
       experiment.algorithm.should == Funtestic::Algorithms::Whiplash
    end

  end

  describe 'persistent configuration' do

    it "should persist algorithm in redis" do
      experiment = Funtestic::Experiment.new('basket_text', :alternatives => ['Basket', "Cart"], :algorithm => Funtestic::Algorithms::Whiplash)
      experiment.save

      e = Funtestic::Experiment.find('basket_text')
      e.should == experiment
      e.algorithm.should == Funtestic::Algorithms::Whiplash
    end
    
    it "should persist a new experiment in redis, that does not exist in the configuration file" do
      experiment = Funtestic::Experiment.new('foobar', :alternatives => ['tra', 'la'], :algorithm => Funtestic::Algorithms::Whiplash)
      experiment.save

      e = Funtestic::Experiment.find('foobar')
      e.should == experiment
      e.alternatives.collect{|a| a.name}.should == ['tra', 'la']
    end
  end

  describe 'deleting' do
    it 'should delete itself' do
      experiment = Funtestic::Experiment.new('basket_text', :alternatives => [ 'Basket', "Cart"])
      experiment.save

      experiment.delete
      Funtestic.redis.exists('link_color').should be false
      Funtestic::Experiment.find('link_color').should be_nil
    end

    it "should increment the version" do
      experiment.version.should eql(0)
      experiment.delete
      experiment.version.should eql(1)
    end
  end


  describe 'winner' do
    it "should have no winner initially" do
      experiment.winner.should be_nil
    end

    it "should allow you to specify a winner" do
      experiment.save
      experiment.winner = 'red'
      experiment.winner.name.should == 'red'
    end
  end

  describe 'reset' do
    before { experiment.save }
    it 'should reset all alternatives' do
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment.reset

      green.participant_count.should eql(0)
      green.completed_count.should eql(0)
    end

    it 'should reset the winner' do
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment.reset

      experiment.winner.should be_nil
    end

    it "should increment the version" do
      experiment.version.should eql(0)
      experiment.reset
      experiment.version.should eql(1)
    end
  end

  describe 'algorithm' do
    let(:experiment) { Funtestic::Experiment.find_or_create('link_color', 'blue', 'red', 'green') }

    it 'should use the default algorithm if none is specified' do
      experiment.algorithm.should == Funtestic.configuration.algorithm
    end

    it 'should use the user specified algorithm for this experiment if specified' do
      experiment.algorithm = Funtestic::Algorithms::Whiplash
      experiment.algorithm.should == Funtestic::Algorithms::Whiplash
    end
  end

  describe 'next_alternative' do
    let(:experiment) { Funtestic::Experiment.find_or_create('link_color', 'blue', 'red', 'green') }

    it "should always return the winner if one exists" do
      green = Funtestic::Alternative.new('green', 'link_color')
      experiment.winner = 'green'

      experiment.next_alternative.name.should eql('green')
      green.increment_participation

      experiment.next_alternative.name.should eql('green')
    end

    it "should use the specified algorithm if a winner does not exist" do
      experiment.algorithm = Funtestic::Algorithms::Whiplash
      experiment.algorithm.should_receive(:choose_alternative).and_return(Funtestic::Alternative.new('green', 'link_color'))
      experiment.next_alternative.name.should eql('green')
    end
  end

  describe 'single alternative' do
    let(:experiment) { Funtestic::Experiment.find_or_create('link_color', 'blue') }

    it "should always return the color blue" do
      experiment.next_alternative.name.should eql('blue')
    end
  end

  describe 'changing an existing experiment' do
    def same_but_different_alternative
      Funtestic::Experiment.find_or_create('link_color', 'blue', 'yellow', 'orange')
    end

    it "should reset an experiment if it is loaded with different alternatives" do
      experiment.save
      blue.participant_count = 5
      same_experiment = same_but_different_alternative
      same_experiment.alternatives.map(&:name).should eql(['blue', 'yellow', 'orange'])
      blue.participant_count.should eql(0)
    end

    it "should only reset once" do
      experiment.save
      experiment.version.should eql(0)
      same_experiment = same_but_different_alternative
      same_experiment.version.should eql(1)
      same_experiment_again = same_but_different_alternative
      same_experiment_again.version.should eql(1)
    end
  end

  describe 'alternatives passed as non-strings' do
    it "should throw an exception if an alternative is passed that is not a string" do
      lambda { Funtestic::Experiment.find_or_create('link_color', :blue, :red) }.should raise_error
      lambda { Funtestic::Experiment.find_or_create('link_enabled', true, false) }.should raise_error
    end
  end

  describe 'specifying weights' do
    let(:experiment_with_weight) {
      Funtestic::Experiment.find_or_create('link_color', {:name => 'blue', :weight => 1}, {:name =>'red', :weight => 2 })
    }

    it "should work for a new experiment" do
      experiment_with_weight.alternatives.map(&:weight).should == [1, 2]
    end

    it "should work for an existing experiment" do
      experiment.save
      experiment_with_weight.alternatives.map(&:weight).should == [1, 2]
    end
  end

  describe "specifying goals" do
    let(:experiment) {
      new_experiment(["purchase"])
    }

    context "saving experiment" do
      def same_but_different_goals
        Funtestic::Experiment.find_or_create({'link_color' => ["purchase", "refund"]}, 'blue', 'red', 'green')
      end

      before { experiment.save }

      it "can find existing experiment" do
        Funtestic::Experiment.find("link_color").name.should eql("link_color")
      end

      it "should reset an experiment if it is loaded with different goals" do
        same_experiment = same_but_different_goals
        Funtestic::Experiment.find("link_color").goals.should == ["purchase", "refund"]
      end

    end

    it "should have goals" do
      experiment.goals.should eql(["purchase"])
    end

    context "find or create experiment" do
      it "should have correct goals"  do
        experiment = Funtestic::Experiment.find_or_create({'link_color3' => ["purchase", "refund"]}, 'blue', 'red', 'green')
        experiment.goals.should == ["purchase", "refund"]
        experiment = Funtestic::Experiment.find_or_create('link_color3', 'blue', 'red', 'green')
        experiment.goals.should == []
      end
    end
  end

end
