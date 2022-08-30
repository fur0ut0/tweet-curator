# frozen_string_literal: true

require 'json'

require_relative 'twitter_api'
require_relative 'util'

module TweetCurator
   # fetch tweets by Twitter API
   class TweetFetcher
      module Home
         MAX_TWEETS_AVAILABLE = 800
         MAX_TWEETS_PER_REQUEST = 200
      end

      module List
         # NOTE: temporary value since not documented
         MAX_TWEETS_AVAILABLE = 800
         MAX_TWEETS_PER_REQUEST = 200
      end

      def initialize(consumer_key:, consumer_secret:, access_token:, access_token_secret:, logger:)
         @api = TwitterAPI.new(consumer_key: consumer_key,
                               consumer_secret: consumer_secret,
                               access_token: access_token,
                               access_token_secret: access_token_secret,
                               logger: logger)
         @logger = logger
      end

      def fetch_tweet(id, tweet_mode: :extended)
         params = {
            id: id,
            tweet_mode: tweet_mode,
         }
         fetch_entrypoint('/statuses/show.json', params)
      end

      def fetch_list(id, total_count: List::MAX_TWEETS_AVAILABLE, since_id: nil,
                     include_rts: true, tweet_mode: :extended)
         params = {
            list_id: id,
            count: List::MAX_TWEETS_PER_REQUEST,
            include_rts: include_rts,
            tweet_mode: tweet_mode.to_s,
         }
         params[:since_id] = Integer(since_id) if since_id

         repeat_fetching_entrypoint('lists/statuses.json', params, total_count)
      end

      def fetch_home(since_id: nil, include_rts: true, tweet_mode: :extended)
         params = {
            count: Home::MAX_TWEETS_PER_REQUEST,
            include_rts: include_rts,
            tweet_mode: tweet_mode.to_s,
         }
         params[:since_id] = Integer(since_id) if since_id

         repeat_fetching_entrypoint('/statuses/home_timeline.json', params, Home::MAX_TWEETS_AVAILABLE)
      end

      def fetch_entrypoint(entrypoint, params)
         begin
            response = @api.get(entrypoint, params)
         rescue HTTPRetriableError => e
            @logger.info(self.class.name) { %(got "#{e.message}", retry fetching) }
            retry
         end

         Util.parse_json_str(response).tap do |tweets|
            @logger.debug(self.class.name) { tweets }
         end
      end

      def repeat_fetching_entrypoint(entrypoint, params, total_count)
         params = params.dup
         (total_count / params[:count]).ceil.times.reduce([]) do |total_tweets, _|
            tweets = fetch_entrypoint(entrypoint, params)
            break total_tweets if tweets.empty?

            tweets.shift if params[:max_id]  # the first tweet is duplicate
            total_tweets += tweets
            break total_tweets if tweets.size < params[:count]

            params[:max_id] = tweets.last[:id]
            total_tweets
         end
      end
   end
end
