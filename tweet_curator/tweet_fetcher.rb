# frozen_string_literal: true

require_relative 'twitter_api'
require_relative 'env_fetcher'

module TweetCurator
   module Home
      MAX_TWEETS_AVAILABLE = 800
      MAX_TWEETS_PER_REQUEST = 200
   end

   # tweet fetcher
   class TweetFetcher
      def initialize(env_fetcher)
         @api = TwitterAPI.new(consumer_key: env_fetcher.fetch(:TWITTER_CONSUMER_KEY),
                               consumer_secret: env_fetcher.fetch(:TWITTER_CONSUMER_SECRET),
                               access_token: env_fetcher.fetch(:TWITTER_ACCESS_TOKEN),
                               access_token_secret: env_fetcher.fetch(:TWITTER_ACCESS_TOKEN_SECRET))
      end

      # TODO
   end
end
