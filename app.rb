require 'pathname'
require 'optparse'
require 'logger'

require 'twitter'
require 'redis'

require_relative 'lib/frequency'


def main
    # Parse option
    options = {}
    opt_parser = OptionParser.new
    opt_parser.on('-t', '--test')
    opt_parser.on('-s JSON', '--serialize=JSON') { |v| Pathname.new(v) }
    opt_parser.parse!(into: options)

    # Logger
    logger = Logger.new($stderr, progname: 'TweetCurator')

    if options[:test]
        require 'dotenv'
        Dotenv.load
    end

    json_path = options[:serialize]
    # NOTE: JSON.load in Ruby 2.6.3 has a bug, using parse instead
    tweets = JSON.parse(json_path.read, symbolize_names: true) if json_path&.file?
    tweets ||= fetch_timeline_tweets
    JSON.dump(tweets, json_path)

    call_without_abort(logger: logger) do
        frequency_pipeline(tweets, logger: logger)
    end
end

#------------------------------------------------------------------------------
# Pipeline
#------------------------------------------------------------------------------

# Fetch twitter home timeline
def fetch_timeline_tweets
    twitter_client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
        config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    end

    # 'home_timeline' API can retrieve upto 200 tweets
    # Since 800 tweets are available, we call it 4 times
    total_tweets = []
    max_id = nil
    4.times do |i|
        opts = {count: 200, include_rts: true}
        opts[:max_id] = max_id if max_id
        tweets = twitter_client.home_timeline(opts).map(&:attrs)

        last_id = tweets.last[:id]
        tweets.shift if max_id
        max_id = last_id

        total_tweets += tweets
    end

    total_tweets
end

def call_without_abort(logger: nil, &block)
    begin
        yield
    rescue => err
        if logger
            logger.error("Error: " + err.full_message)
        else
            puts err.full_message
        end
    end
end

def frequency_pipeline(tweets, logger: nil)
    min_tweets = tweets.map { |t| Frequency::MinTweet.from_tweet(t) }
    redis = Frequency::MinTweetRedis.new(Redis.new(url: ENV['REDIS_URL']))

    recent_ids = redis.restore(0...5, use_keys: [:id]).map(&:id)
    stop_idx = min_tweets.find_index { |t| recent_ids.include?(t.id) }
    min_tweets = min_tweets[0...stop_idx]

    min_tweets.reverse.each { |t| redis.store(t) }
    logger&.info { "Stored #{min_tweets.size} tweets in Redis" }
end


if $0 == __FILE__
    main
end

