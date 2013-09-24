module Funtestic
  module Persistence
    class SessionAdapter

      def initialize(context)
        @session = context.session
        @session[:funtestic] ||= {}
      end

      def [](key)
        @session[:funtestic][key]
      end

      def []=(key, value)
        @session[:funtestic][key] = value
      end

      def delete(key)
        @session[:funtestic].delete(key)
      end

      def keys
        @session[:funtestic].keys
      end

    end
  end
end