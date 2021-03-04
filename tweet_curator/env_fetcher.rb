# frozen_string_literal: true

module TweetCurator
   # environmental variable fetcher
   class EnvFetcher
      # load dotenv config
      def load_dotenv
         require 'dotenv'
         Dotenv.load
      end

      # get environmental variable by key
      def get(key)
         ENV[key.to_s]
      end

      # get environmental variable by key, raise if unset
      # @raise KeyError environmental variable is unset
      def fetch(key)
         ENV.fetch(key.to_s) { |k| raise KeyError, "unset environmental variable: #{k}" }
      end
   end
end
