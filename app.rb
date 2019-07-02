require 'pathname'
require 'optparse'
require 'time'
require 'logger'

require 'twitter'
require 'redis'


def main
    # Parse option
    options = {}
    OptionParser.new.tap { |opt|
        opt.on('-t', '--test')
        opt.on('-s JSON', '--serialize=JSON') { |v| Pathname.new(v) }
    }.parse(into: options)

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
        save_shrinked_tweets_to_redis(tweets)
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

    return twitter_client.home_timeline(count: 200, include_rts: true).map(&:attrs)
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

def save_shrinked_tweets_to_redis(tweets)
    shrinked = tweets.map { |t| shrink_tweet(t) }
    redis = Redis.new(url: ENV['REDIS_URL'])
    save_tweets_to_redis(shrinked, redis)
end


# Shrink tweet attribute designed to collect statistic
def shrink_tweet(tweet)
    def determine_type(tweet)
        return 'retweet' if tweet[:retweeted_status]
        return 'reply'   if tweet[:in_reply_to_status_id]
        return 'quoted'  if tweet[:quoted_status]
        return 'normal'
    end

    {
        id:          tweet[:id],
        timestamp:   Time.parse(tweet[:created_at]),
        screen_name: tweet[:user][:screen_name],
        type:        determine_type(tweet),
    }
end

def save_tweets_to_redis(tweets, redis)
    prefix = 'tweets'

    # Ignore already saved tweets
    # Using tweet ID to check existence
    recent_saved_ids = redis.lrange("#{prefix}:id", 0, 4).map(&:to_i) # NOTE: I think 5 is enough
    stop_idx = tweets.find_index { |t| recent_saved_ids.include?(t[:id]) }
    puts "Stop: #{stop_idx} #{tweets.size}"
    tweets = tweets[0...stop_idx]

    tweets = tweets.reverse # Storing from older one
    tweets.each do |attr|
        attr.each_pair do |key,val|
            redis.lpush("#{prefix}:#{key}", val)
        end
    end
end

if $0 == __FILE__
    main
end
