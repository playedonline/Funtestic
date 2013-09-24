%w[session_adapter cookie_adapter].each do |f|
  require "funtestic/persistence/#{f}"
end

module Funtestic
  module Persistence
    ADAPTERS = {
      :cookie => Funtestic::Persistence::CookieAdapter,
      :session => Funtestic::Persistence::SessionAdapter
    }

    def self.adapter
      if persistence_config.is_a?(Symbol)
        adapter_class = ADAPTERS[persistence_config]
        raise Funtestic::InvalidPersistenceAdapterError unless adapter_class
      else
        adapter_class = persistence_config
      end
      adapter_class
    end

    private

    def self.persistence_config
      Funtestic.configuration.persistence
    end
  end
end