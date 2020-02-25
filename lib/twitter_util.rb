require "twitter"

module TwitterUtil
  # Create Twitter REST client
  # @return [Twitter::REST::Client]
  def self.create_rest_client(consumer_key:, consumer_secret:,
                              access_token:, access_token_secret:)
    Twitter::REST::Client.new do |config|
      config.consumer_key = consumer_key
      config.consumer_secret = consumer_secret
      config.access_token = access_token
      config.access_token_secret = access_token_secret
    end
  end

  # Fetch twitter home timeline
  # @param twitter_client [Twitter::REST::Client] Twitter client
  # @param since_id [Integer] Returns only statuses with an ID greater than (that is, more recent than) the specified ID.
  # @return [Array<Twitter::Tweet>]
  def self.fetch_timeline(twitter_client, since_id = nil)
    # 'home_timeline' API can retrieve upto 200 tweets
    # Since 800 tweets are available, we call it 4 times
    max_id = nil
    total_tweets = []
    4.times do |i|
      opts = { count: 200, include_rts: true }
      opts[:max_id] = max_id if max_id
      opts[:since_id] = since_id if since_id
      tweets = twitter_client.home_timeline(opts)
      break if tweets.empty?

      last_id = tweets.last.attrs[:id]
      tweets.shift if max_id
      max_id = last_id

      total_tweets += tweets
    end

    total_tweets
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
