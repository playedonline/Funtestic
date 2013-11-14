module Funtestic
  class Experiment
    attr_accessor :name
    attr_writer :algorithm
    attr_accessor :goals
    attr_accessor :alternatives
    attr_accessor :max_participants

    def initialize(name, options = {})
      @name = name.to_s

      alts = options[:alternatives] || []

      if alts.length == 1
        if alts[0].is_a? Hash
          alts = alts[0].map { |k, v| {k => v} }
        end
      end

      if alts.empty?
        exp_config = Funtestic.configuration.experiment_for(name)
        if exp_config
          alts = load_alternatives_from_configuration
          options[:goals] = load_goals_from_configuration
          options[:algorithm] = exp_config[:algorithm]
          options[:max_participants] = exp_config[:max_participants]
        end
      end

      self.alternatives = alts
      self.goals = options[:goals]
      self.algorithm = options[:algorithm]
      self.max_participants = options[:max_participants]
    end

    def self.all
      Funtestic.redis.smembers(:experiments).map { |e| find(e) }
    end

    def self.active_experiments_names
      Funtestic.redis.smembers(:experiments)
    end

    def self.find(name)
      if Funtestic.redis.exists(name)
        obj = self.new name
        obj.load_from_redis
      else
        obj = nil
      end
      obj
    end

    def self.find_or_create(label, *alternatives)
      experiment_name_with_version, goals = normalize_experiment(label)
      name = experiment_name_with_version.to_s.split(':')[0]

      exp = self.new name, :alternatives => alternatives, :goals => goals
      exp.save
      exp
    end

    def save
      validate!

      if new_record?
        Funtestic.redis.sadd(:experiments, name)
        set_start_time
        @alternatives.reverse.each do |a|
          Funtestic.redis.lpush(name, a.name)
          a.set_unique_id self.version
        end
        @goals.reverse.each { |a| Funtestic.redis.lpush(goals_key, a) } unless @goals.nil?
      else

        existing_alternatives = load_alternatives_from_redis
        existing_goals = load_goals_from_redis
        unless existing_alternatives == @alternatives.map(&:name) && existing_goals == @goals
          reset
          @alternatives.each(&:delete)
          delete_goals
          Funtestic.redis.del(@name)
          @alternatives.reverse.each do |a|
            Funtestic.redis.lpush(name, a.name)
            a.set_unique_id self.version
          end
          @goals.reverse.each { |a| Funtestic.redis.lpush(goals_key, a) } unless @goals.nil?
        end
      end

      Funtestic.redis.hset(experiment_config_key, :algorithm, algorithm.to_s)
      self
    end

    def validate!
      if @alternatives.empty? && Funtestic.configuration.experiment_for(@name).nil?
        raise ExperimentNotFound.new("Experiment #{@name} not found")
      end
      @alternatives.each { |a| a.validate! }
      unless @goals.nil? || goals.kind_of?(Array)
        raise ArgumentError, 'Goals must be an array'
      end
    end

    def new_record?
      !Funtestic.redis.exists(name)
    end

    def ==(obj)
      self.name == obj.name
    end

    def [](name)
      alternatives.find { |a| a.name == name }
    end

    def algorithm
      @algorithm ||= Funtestic.configuration.algorithm
    end

    def algorithm=(algorithm)
      @algorithm = algorithm.is_a?(String) ? algorithm.constantize : algorithm
    end

    def alternatives=(alts)
      @alternatives = alts.map do |alternative|
        if alternative.kind_of?(Funtestic::Alternative)
          alternative
        else
          Funtestic::Alternative.new(alternative, @name)
        end
      end
    end

    def event_types
      event_names = []
      alternatives = @alternatives.each do |alternative|
        event_names = event_names + alternative.events_hash.keys
      end
      event_names.uniq
    end

    def event_totals
      totals_hash = {}
      @alternatives.each do |alternative|
        alternative.events_hash.each do |event_name, amount|
          totals_hash[event_name] = totals_hash[event_name].present? ? (totals_hash[event_name].to_i+amount.to_i) : amount.to_i
        end

      end
      totals_hash
    end


    def winner
      if w = Funtestic.redis.hget(:experiment_winner, name)
        Funtestic::Alternative.new(w, name)
      else
        nil
      end
    end

    def winner=(winner_name)
      Funtestic.redis.hset(:experiment_winner, name, winner_name.to_s)
    end

    def participant_count
      alternatives.inject(0) { |sum, a| sum + a.participant_count }
    end

    def control
      alternatives.first
    end

    def reset_winner
      Funtestic.redis.hdel(:experiment_winner, name)
    end

    def start_time
      self.class.find_start_time_by_name_and_version @name, self.version
    end

    def self.find_start_time_by_name_and_version (name, version)
      t = Funtestic.redis.hget(:experiment_start_times, "#{name}:#{version}")

      # Backwards compatibility for existing experiments (from before adding exp. version to name)
      if (t.nil? && version.to_s == "0")
        t = Funtestic.redis.hget(:experiment_start_times, name)
      end

      if t
        # Check if stored time is an integer
        if t =~ /^[-+]?[0-9]+$/
          t = Time.at(t.to_i)
        else
          t = Time.parse(t)
        end
      end
    end

    def self.find_end_time_by_name_and_version (name, version)
      t = Funtestic.redis.hget(:experiment_end_times, "#{name}:#{version}")
      if t
        # Check if stored time is an integer
        if t =~ /^[-+]?[0-9]+$/
          t = Time.at(t.to_i)
        else
          t = Time.parse(t)
        end
      end
    end

    def next_alternative
      winner || random_alternative
    end

    def random_alternative
      if alternatives.length > 1
        algorithm.choose_alternative(self)
      else
        alternatives.first
      end
    end

    def version
      @version ||= (Funtestic.redis.get("#{name.to_s}:version").to_i || 0)
    end

    def increment_version
      @version = Funtestic.redis.incr("#{name}:version")
    end

    def key
      if version.to_i > 0
        "#{name}:#{version}"
      else
        name
      end
    end

    def goals_key
      "#{name}:goals"
    end

    def finished_key
      "#{key}:finished"
    end

    def attempt_key
      "#{key}:attempt"
    end

    def reset
      alternatives.each(&:reset)
      reset_winner
      set_end_time
      increment_version
      set_start_time
      alternatives.each { |alt| alt.set_unique_id(version) }
    end

    def set_start_time
      Funtestic.redis.hset(:experiment_start_times, "#{@name}:#{self.version}" , Time.now.to_i)
    end

    def set_end_time
      Funtestic.redis.hset(:experiment_end_times, "#{@name}:#{self.version}" , Time.now.to_i)
    end

    def delete
      set_end_time
      alternatives.each(&:delete)
      reset_winner
      Funtestic.redis.srem(:experiments, name)
      Funtestic.redis.del(name)
      delete_goals
      increment_version
    end

    def delete_goals
      Funtestic.redis.del(goals_key)
    end

    def load_from_redis
      exp_config = Funtestic.redis.hgetall(experiment_config_key)
      self.algorithm = exp_config['algorithm']
      self.alternatives = load_alternatives_from_redis
      self.goals = load_goals_from_redis
    end

    protected

    def self.normalize_experiment(label)
      if Hash === label
        experiment_name = label.keys.first
        goals = label.values.first
      else
        experiment_name = label
        goals = []
      end
      return experiment_name, goals
    end

    def experiment_config_key
      "experiment_configurations/#{@name}"
    end

    def load_goals_from_configuration
      goals = Funtestic.configuration.experiment_for(@name)[:goals]
      if goals.nil?
        goals = []
      else
        goals.flatten
      end
    end

    def load_goals_from_redis
      Funtestic.redis.lrange(goals_key, 0, -1)
    end

    def load_alternatives_from_configuration
      alts = Funtestic.configuration.experiment_for(@name)[:alternatives]
      raise ArgumentError, "Experiment configuration is missing :alternatives array" unless alts
      if alts.is_a?(Hash)
        alts.keys
      else
        alts.flatten
      end
    end

    def load_alternatives_from_redis
      case Funtestic.redis.type(@name)
        when 'set' # convert legacy sets to lists
          alts = Funtestic.redis.smembers(@name)
          Funtestic.redis.del(@name)
          alts.reverse.each { |a| Funtestic.redis.lpush(@name, a) }
          Funtestic.redis.lrange(@name, 0, -1)
        else
          Funtestic.redis.lrange(@name, 0, -1)
      end
    end

  end
end
