require "json"

module Funtestic
  module Persistence
    class CookieAdapter

      EXPIRES = Time.now + 31536000 # One year from now
      PREFIX = 'funtestic'

      def initialize(context)
        @is_sinatra = context.is_a?(Sinatra::Base)
        if @is_sinatra
          @context = context
          @cookies = @context.request.cookies
        else
          @cookies = context.send(:cookies)
        end
      end

      def [](key)
        hash[key]
      end

      def []=(key, value)
        set_cookie(hash.merge(key => value))
      end

      def delete(key)
        set_cookie(hash.tap { |h| h.delete(key) })
      end

      def keys
        hash.keys
      end

      private

      def set_cookie(value)
        new_cooike_content= {
            value: JSON.generate(value),
            expires: EXPIRES
        }

        if @is_sinatra
          @context.response.set_cookie PREFIX, new_cooike_content.merge(path: '/')
          @cookies = @context.request.cookies
        else
          @cookies[PREFIX] = new_cooike_content
        end
      end

      def hash
        if @cookies[PREFIX]
          begin
            JSON.parse(@cookies[PREFIX])
          rescue JSON::ParserError
            {}
          end
        else
          {}
        end
      end

    end
  end
end
