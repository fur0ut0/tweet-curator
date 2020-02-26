require "twitter"

module TwitterUtil
  module RestClient
    # Create Twitter REST client
    # @return [Twitter::REST::Client]
    def self.create(consumer_key:, consumer_secret:,
                    access_token:, access_token_secret:)
      Twitter::REST::Client.new do |config|
        config.consumer_key = consumer_key
        config.consumer_secret = consumer_secret
        config.access_token = access_token
        config.access_token_secret = access_token_secret
      end
    end
  end

  module Timeline
    MAX_AVAILABLE = 800
    MAX_PER_REQUEST = 200

    # Fetch twitter home timeline
    # @param twitter_client [Twitter::REST::Client] Twitter client
    # @param since_id [Integer] Returns only statuses with an ID greater than (that is, more recent than) the specified ID.
    # @return [Array<Twitter::Tweet>]
    def self.fetch(twitter_client, since_id = nil)
      max_id = nil
      total_tweets = []
      (MAX_AVAILABLE / MAX_AVAILABLE).ceil.times do |i|
        opts = { count: MAX_PER_REQUEST, include_rts: true }
        opts[:max_id] = max_id if max_id
        opts[:since_id] = since_id if since_id
        tweets = twitter_client.home_timeline(opts)
        break if tweets.empty?

        last_id = tweets.last.attrs[:id]
        tweets.shift if max_id
        max_id = last_id

        total_tweets += tweets
        break if tweets.size < MAX_PER_REQUEST
      end
      total_tweets
    end
  end
end

module Twitter
  class Tweet
    def to_h
      {
        url: url,
        attrs: attrs,
      }
    end
  end
end
