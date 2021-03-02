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
      def initialize(consumer_key:, consumer_secret:, access_token:, access_token_secret:)
         @api = TwitterAPI.new(consumer_key: consumer_key,
                               consumer_secret: consumer_secret,
                               access_token: access_token,
                               access_token_secret: access_token_secret)
      end

      # TODO
   end
end
