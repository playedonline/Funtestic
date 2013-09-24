module Funtestic
  class Alternative
    attr_accessor :name
    attr_accessor :experiment_name
    attr_accessor :weight
    attr_accessor :channel

    def initialize(name, experiment_name)
      @experiment_name = experiment_name
      if Hash === name
        @name = name[:name]
        @weight = name[:percent]
        @channel = name[:channel]
      else
        @name = name
        @weight = 1
      end
    end

    def self.get_all_historical_alternatives
      Funtestic.redis.lrange('all_alternative_ids', 0, -1).map do |alt_id|
        alt_info = Funtestic.redis.hmget "alternative_#{alt_id}_info", 'abtest_name', 'abtest_version', 'alternative_name', 'channel'
        {:alt_id => alt_id, :abtest_name => alt_info[0], :abtest_version => alt_info[1], :alternative_name => alt_info[2], :channel => alt_info[3] }
      end
    end

    def set_unique_id experiment_version
      if Funtestic.redis.hsetnx key, 'unique_id', -1
        next_id = Funtestic.redis.incrby 'alternative_next_id', 1
        Funtestic.redis.hset key, 'unique_id', next_id

        # Will be used to fetch all historical data
        Funtestic.redis.lpush 'all_alternative_ids', next_id
        Funtestic.redis.hmset "alternative_#{next_id}_info", 'abtest_name', experiment_name, 'abtest_version', experiment_version, 'alternative_name', name, 'channel', channel
      end
    end

    def self.find_alternative_unique_id experiment_name, alternative_name
      alternative_key = build_key experiment_name, alternative_name
      id = Funtestic.redis.hget alternative_key, 'unique_id'

      # Just in case set_unique_id (which is not atomic and doesn't use locks is just in the middle of execution)
      if id.to_s == "-1"
        sleep 0.2.seconds
        id = Funtestic.redis.hget alternative_key, 'unique_id'
      end

      id
    end

    def to_s
      name
    end

    def goals
      self.experiment.goals
    end

    def participant_count
      Funtestic.redis.hget(key, 'participant_count').to_i
    end

    def participant_count=(count)
      Funtestic.redis.hset(key, 'participant_count', count.to_i)
    end

    def completed_count(goal = nil)
      field = set_field(goal)
      Funtestic.redis.hget(key, field).to_i
    end

    def conversion_count(goal = nil)
      field = set_conversion_field(goal)
      Funtestic.redis.hget(key, field).to_i
    end

    def attempt_count(goal = nil)
      field = set_attempt_field(goal)
      Funtestic.redis.hget(key, field).to_i
    end

    def events_hash(goal = nil)
      Funtestic.redis.hgetall(key+":events")
    end

    def all_completed_count
      if goals.empty?
        completed_count
      else
        goals.inject(completed_count) do |sum, g|
          sum + completed_count(g)
        end
      end
    end

    def all_conversion_count
      if goals.empty?
        conversion_count
      else
        goals.inject(conversion_count) do |sum, g|
          sum + conversion_count(g)
        end
      end
    end

    def all_attempt_count
      if goals.empty?
        attempt_count
      else
        goals.inject(attempt_count) do |sum, g|
          sum + attempt_count(g)
        end
      end
    end

    def unfinished_count
      participant_count - all_completed_count
    end

    def set_field(goal)
      field = "completed_count"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_conversion_field(goal)
      field = "conversion_count"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_attempt_field(goal)
      field = "attempt_count"
      field += ":" + goal unless goal.nil?
      return field
    end

    def set_completed_count (count, goal = nil)
      field = set_field(goal)
      Funtestic.redis.hset(key, field, count.to_i)
    end

    def increment_participation
      Funtestic.redis.hincrby key, 'participant_count', 1
    end

    def increment_completion(goal = nil)
      field = set_field(goal)
      Funtestic.redis.hincrby(key, field, 1)
    end

    def increment_conversion(goal = nil)
      field = set_conversion_field(goal)
      Funtestic.redis.hincrby(key, field, 1)
    end

    def increment_attempt(goal = nil)
      field = set_attempt_field(goal)
      Funtestic.redis.hincrby(key, field, 1)
    end

    def increment_events(event_data = {})
      event_data.each do |counter_name, increase_by|
        Funtestic.redis.hincrby(key+":events", counter_name, increase_by)
      end
    end

    def control?
      experiment.control.name == self.name
    end

    def conversion_rate(goal = nil)
      return 0 if participant_count.zero?
      (conversion_count(goal).to_f)/participant_count.to_f
    end

    def single_conversion_rate(goal = nil)
      return 0 if participant_count.zero?
      (completed_count(goal).to_f)/participant_count.to_f
    end

    def experiment
      Funtestic::Experiment.find(experiment_name)
    end

    def z_score(goal = nil)
      # CTR_E = the CTR within the experiment split
      # CTR_C = the CTR within the control split
      # E = the number of impressions within the experiment split
      # C = the number of impressions within the control split

      control = experiment.control

      alternative = self

      return 'N/A' if control.name == alternative.name

      ctr_e = alternative.conversion_rate(goal)
      ctr_c = control.conversion_rate(goal)


      e = alternative.participant_count
      c = control.participant_count

      return 0 if ctr_c.zero?

      standard_deviation = ((ctr_e / ctr_c**3) * ((e*ctr_e)+(c*ctr_c)-(ctr_c*ctr_e)*(c+e))/(c*e)) ** 0.5

      z_score = ((ctr_e / ctr_c) - 1) / standard_deviation
    end

    def save
      Funtestic.redis.hsetnx key, 'participant_count', 0
      Funtestic.redis.hsetnx key, 'completed_count', 0
      Funtestic.redis.hsetnx key, 'conversion_count', 0
    end

    def validate!
      unless String === @name || hash_with_correct_values?(@name)
        raise ArgumentError, 'Alternative must be a string'
      end
    end

    def reset
      Funtestic.redis.hmset key, 'participant_count', 0, 'completed_count', 0, 'conversion_count', 0

      Funtestic.redis.del key+":events"

      Funtestic.redis.hdel key, 'unique_id'

      unless goals.empty?
        goals.each do |g|
          field = "completed_count:#{g}"
          Funtestic.redis.hset key, field, 0
          field = "conversion_count:#{g}"
          Funtestic.redis.hset key, field, 0
        end
      end
    end

    def delete
      Funtestic.redis.del(key)
      Funtestic.redis.del(key+":events")
    end

    private

    def hash_with_correct_values?(name)
      Hash === name && String === name.keys.first && Float(name.values.first) rescue false
    end

    def key
      self.class.build_key experiment_name, name
    end

    def self.build_key experiment_name, alternative_name
      "#{experiment_name}:#{alternative_name}"
    end

  end
end
