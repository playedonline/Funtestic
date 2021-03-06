module Funtestic
  class Metric
    attr_accessor :name
    attr_accessor :experiments

    def initialize(attrs = {})
      attrs.each do |key,value|
        if self.respond_to?("#{key}=")
          self.send("#{key}=", value)
        end
      end
    end

    def self.load_from_redis(name)
      metric = Funtestic.redis.hget(:metrics, name)
      if metric
        experiment_names = metric.split(',')

        experiments = experiment_names.collect do |experiment_name|
          Funtestic::Experiment.find(experiment_name)
        end

        Funtestic::Metric.new(:name => name, :experiments => experiments)
      else
        nil
      end
    end

    def self.load_from_configuration(name)
      metrics = Funtestic.configuration.metrics
      if metrics && metrics[name]
        Funtestic::Metric.new(:experiments => metrics[name], :name => name)
      else
        nil
      end
    end

    def self.find(name)
      name = name.intern if name.is_a?(String)
      metric = load_from_configuration(name)
      metric = load_from_redis(name) if metric.nil?
      metric
    end

    def self.possible_experiments(metric_name)
      experiments = []
      metric  = Funtestic::Metric.find(metric_name)
      if metric
        experiments << metric.experiments
      end
      experiment = Funtestic::Experiment.find(metric_name)
      if experiment
        experiments << experiment
      end
      experiments.flatten
    end

    def save
      Funtestic.redis.hset(:metrics, name, experiments.map(&:name).join(','))
    end

    def complete!
      experiments.each do |experiment|
        experiment.complete!
      end
    end

    private

    def self.normalize_metric(label)
      if Hash === label
        metric_name = label.keys.first
        goals = label.values.first
      else
        metric_name = label
        goals = []
      end
      return metric_name, goals
    end
  end
end