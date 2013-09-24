module Funtestic
  class Trial
    attr_accessor :experiment
    attr_accessor :goals

    def initialize(attrs = {})
      self.experiment = attrs[:experiment]  if !attrs[:experiment].nil?
      self.alternative = attrs[:alternative] if !attrs[:alternative].nil?
      self.goals = attrs[:goals].nil? ? [] : attrs[:goals]
    end

    def alternative
      @alternative ||=  if experiment.winner
                          experiment.winner
                        end
    end

    def attempt!
      if alternative
        if self.goals.empty?
          alternative.increment_attempt
        else
          self.goals.each {|g| alternative.increment_attempt(g)}
        end
      end
    end

    def complete!
      if alternative
        if self.goals.empty?
          alternative.increment_completion
          alternative.increment_conversion
        else
          self.goals.each {|g| alternative.increment_completion(g)}
          self.goals.each {|g| alternative.increment_conversion(g)}
        end
      end
    end

    def conversion!
      if alternative
        if self.goals.empty?
          alternative.increment_conversion
        else
          self.goals.each {|g| alternative.increment_conversion(g)}
        end
      end
    end

    def event(event_data = {})
      if alternative
        alternative.increment_events(event_data)
      end
    end


    def choose!
      choose
      record!
    end

    def record!
      alternative.increment_participation
    end

    def choose
      self.alternative = experiment.next_alternative
    end

    def alternative=(alternative)
      @alternative = if alternative.kind_of?(Funtestic::Alternative)
        alternative
      else
        self.experiment.alternatives.find{|a| a.name == alternative }
      end
    end
  end
end
