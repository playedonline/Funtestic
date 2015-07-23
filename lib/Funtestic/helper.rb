module Funtestic
  module Helper

    def get_alternative_for_user_or_default(experiment_name, default)
      experiment = Funtestic::Experiment.find(experiment_name)
      if (experiment.present?) && ab_user[experiment.key]
        ab_user[experiment.key]
      else
        default
      end
    end

    def is_participating?(experiment_name)
      experiment = Funtestic::Experiment.find(experiment_name)

      # Return true if the user's hash has the experiment's key
      (experiment.present?) && ab_user[experiment.key]
    end

    def ab_test(metric_descriptor, control=nil, *alternatives)
      if RUBY_VERSION.match(/1\.8/) && alternatives.length.zero? && ! control.nil?
        puts 'WARNING: You should always pass the control alternative through as the second argument with any other alternatives as the third because the order of the hash is not preserved in ruby 1.8'
      end

      # Check if array is passed to ab_test: ab_test('name', ['Alt 1', 'Alt 2', 'Alt 3'])
      if control.is_a? Array and alternatives.length.zero?
        control, alternatives = control.first, control[1..-1]
      end

      begin
      experiment_name_with_version, goals = normalize_experiment(metric_descriptor)
      experiment_name = experiment_name_with_version.to_s.split(':')[0]
      experiment = Funtestic::Experiment.new(experiment_name, :alternatives => [control].compact + alternatives, :goals => goals)
      control ||= experiment.control && experiment.control.name

        ret = if Funtestic.configuration.enabled
          if (experiment.new_record?)
            call_experiment_created_hook(experiment)
          end
          experiment.save
          start_trial( Trial.new(:experiment => experiment) )
        else
          control_variable(control)
        end

      rescue => e
        raise(e) unless Funtestic.configuration.db_failover
        Funtestic.configuration.db_failover_on_db_error.call(e)

        if Funtestic.configuration.db_failover_allow_parameter_override && override_present?(experiment_name)
          ret = override_alternative(experiment_name)
        end
      ensure
        unless ret
          ret = control_variable(control)
        end
      end

      if block_given?
        if defined?(capture) # a block in a rails view
          block = Proc.new { yield(ret) }
          concat(capture(ret, &block))
          false
        else
          yield(ret)
        end
      else
        ret
      end
    end

    def attempt_for_experiment(experiment, options = {:multiple_conversion => true})
      return true unless experiment.winner.nil?
      multiple_conversion = options[:multiple_conversion]
      if !multiple_conversion && ab_user[experiment.attempt_key]
        return true
      else
        alternative_name = ab_user[experiment.key]
        trial = Trial.new(:experiment => experiment, :alternative => alternative_name, :goals => options[:goals])
        trial.attempt!
        ab_user[experiment.attempt_key] = true

        # Let the application do whatever it wants with the attempt for this alternative
        call_attempt_reported_hook Funtestic::Alternative.find_alternative_unique_id(experiment.name, alternative_name)

      end
    end

    def finish_experiment(experiment, options = {:multiple_conversion => true})
      return true unless experiment.winner.nil?
      multiple_conversion = options[:multiple_conversion]
      if !multiple_conversion  && ab_user[experiment.finished_key]
        return true
      else
        alternative_name = ab_user[experiment.key]
        trial = Trial.new(:experiment => experiment, :alternative => alternative_name, :goals => options[:goals])

        if (ab_user[experiment.finished_key] != true)
          trial.complete!
          ab_user[experiment.finished_key] = true
        else
          trial.conversion!
        end

        # Let the application do whatever it wants with the conversion for this alternative
        call_finish_reported_hook Funtestic::Alternative.find_alternative_unique_id(experiment.name, alternative_name)

      end
    end

    def track_event(experiment, event_data = {}) #event_data is hash of event name and how much incrememnt by
      return true unless experiment.winner.nil?

        alternative_name = ab_user[experiment.key]
        trial = Trial.new(:experiment => experiment, :alternative => alternative_name)
        trial.event(event_data)

    end

    def report_attempt(metric_descriptor, options = {:multiple_conversion => true})
      return if exclude_visitor? || Funtestic.configuration.disabled?
      metric_descriptor, goals = normalize_experiment(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)

      if experiments.any?
        experiments.each do |experiment|
          # Make sure the user is a participant
          if ab_user[experiment.key]
            attempt_for_experiment(experiment, options.merge(:goals => goals))
          end
        end
      end
    rescue => e
      raise unless Funtestic.configuration.db_failover
      Funtestic.configuration.db_failover_on_db_error.call(e)

    end

    def track_alternative_event(experiment, alternative_name, event_data = {}) #event_data is hash of event name and how much incrememnt by
      return true unless experiment.winner.nil?

      trial = Trial.new(:experiment => experiment, :alternative => alternative_name)
      trial.event(event_data)

    end

    def finished(metric_descriptor, options = {:multiple_conversion => true})
      return if exclude_visitor? || Funtestic.configuration.disabled?
      metric_descriptor, goals = normalize_experiment(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)

      if experiments.any?
        experiments.each do |experiment|
          # Make sure the user is a participant
          if ab_user[experiment.key]
            finish_experiment(experiment, options.merge(:goals => goals))
          end
        end
      end
    rescue => e
      raise unless Funtestic.configuration.db_failover
      Funtestic.configuration.db_failover_on_db_error.call(e)
    end


    def abtest_event(metric_descriptor, event_data = {})
      return if exclude_visitor? || Funtestic.configuration.disabled?
      metric_descriptor, goals = normalize_experiment(metric_descriptor)
      experiments = Metric.possible_experiments(metric_descriptor)

      if experiments.any?
        experiments.each do |experiment|
          track_event(experiment, event_data)
        end
      end
    rescue => e
      raise unless Funtestic.configuration.db_failover
      Funtestic.configuration.db_failover_on_db_error.call(e)
    end

    def abtest_event_for_alternative(experiment_name, alternative_name, event_data = {})
      return if exclude_visitor? || Funtestic.configuration.disabled?
      experiments = Metric.possible_experiments(experiment_name)

      if experiments.any? and alternative_name.present?
        track_alternative_event(experiments.first, alternative_name, event_data)
      end
    rescue => e
      raise unless Funtestic.configuration.db_failover
      Funtestic.configuration.db_failover_on_db_error.call(e)
    end

    def override_present?(experiment_name)
      defined?(params) && params[experiment_name]
    end

    def override_alternative(experiment_name)
      params[experiment_name] if override_present?(experiment_name)
    end

    def begin_experiment(experiment, alternative_name = nil)
      alternative_name ||= experiment.control.name
      ab_user[experiment.key] = alternative_name
      alternative_name
    end

    def ab_user
      @ab_user ||= Funtestic::Persistence.adapter.new(self)
    end

    def get_user_abtests_alt_ids
      # Ignore keys with ':finished'/':attempt', which mark conversions/conversion attempt, we want to only go over keys that mark participating
      # in a test
      ab_user.keys.reject { |key| key.ends_with?(':finished', ':attempt') }.map { |key| Alternative.find_alternative_unique_id(key.split(':')[0], ab_user[key]) }.join(',')
    end

    def exclude_visitor?
      instance_eval(&Funtestic.configuration.ignore_filter)
    end

    def not_allowed_to_test?(experiment_key)
      !Funtestic.configuration.allow_multiple_experiments && doing_other_tests?(experiment_key)
    end

    def doing_other_tests?(experiment_key)
      keys_without_experiment(ab_user.keys, experiment_key).length > 0
    end

    def clean_old_versions(experiment)

      # Delete old version of the current experiment
      old_versions(experiment).each do |old_key|
        ab_user.delete old_key
      end

      # Also, delete experiments which have already been deleted
      # (keeping the Funtestic cookie small if working with cookie provider)
      active_experiments = Experiment.active_experiments_names
      inactive_keys = ab_user.keys.select { |k| nil == active_experiments.detect { |exp| k.match(Regexp.new(exp))} }
      inactive_keys.each{|k| ab_user.delete k}

    end

    def old_versions(experiment)
      if experiment.version > 0
        keys = ab_user.keys.select { |k| k.match(Regexp.new(experiment.name)) }
        keys_without_experiment(keys, experiment.key)
      else
        []
      end
    end

    def is_robot?
      request.user_agent =~ Funtestic.configuration.robot_regex
    end

    def is_ignored_ip_address?
      return false if Funtestic.configuration.ignore_ip_addresses.empty?

      Funtestic.configuration.ignore_ip_addresses.each do |ip|
        return true if request.ip == ip || (ip.class == Regexp && request.ip =~ ip)
      end
      false
    end

    protected

    def normalize_experiment(metric_descriptor)
      if Hash === metric_descriptor
        experiment_name = metric_descriptor.keys.first
        goals = Array(metric_descriptor.values.first)
      else
        experiment_name = metric_descriptor
        goals = []
      end
      return experiment_name, goals
    end

    def control_variable(control)
      Hash === control ? control.keys.first : control
    end

    def start_trial(trial)
      experiment = trial.experiment
      if override_present?(experiment.name)
        ret = override_alternative(experiment.name)
        ab_user[experiment.key] = ret if Funtestic.configuration.store_override
      elsif ! experiment.winner.nil?
        ret = experiment.winner.name
      else
        clean_old_versions(experiment)
        if exclude_visitor? || not_allowed_to_test?(experiment.key)
          ret = experiment.control.name
        else
          if ab_user[experiment.key]
            ret = ab_user[experiment.key]
          else

            if experiment.max_participants > experiment.participant_count
              trial.choose!
              call_trial_choose_hook(trial)
              ret = begin_experiment(experiment, trial.alternative.name)
            elsif experiment.end_time.nil?
              # experiment.set_end_time(experiment.time_to_finish.from_now)
              experiment.set_end_time
            end

          end
        end
      end

      ret
    end

    def call_attempt_reported_hook(alternative_id)
      send(Funtestic.configuration.on_attempt_reported, alternative_id) if Funtestic.configuration.on_attempt_reported
    end

    def call_finish_reported_hook(alternative_id)
      send(Funtestic.configuration.on_finish_reported, alternative_id) if Funtestic.configuration.on_finish_reported
    end

    def call_trial_choose_hook(trial)
      send(Funtestic.configuration.on_trial_choose, trial) if Funtestic.configuration.on_trial_choose
    end

    def call_experiment_created_hook(experiment)
      send(Funtestic.configuration.on_experiment_created, experiment) if Funtestic.configuration.on_experiment_created
    end


    #def call_trial_complete_hook(trial)
    #  send(Funtestic.configuration.on_trial_complete, trial) if Funtestic.configuration.on_trial_complete
    #end

    def keys_without_experiment(keys, experiment_key)
      # Remove keys that belong to the experiment in experiment_key (ie - 'experiment_key', 'experiment_key:finished', 'experiment_key:attempt')
      keys.reject { |k| k.match(Regexp.new("^#{experiment_key}(:finished)?(:attempt)?$")) }
    end
  end
end
