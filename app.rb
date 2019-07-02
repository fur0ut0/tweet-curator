require 'pathname'
require 'optparse'
require 'time'

require 'twitter'
require 'redis'


# Fetch twitter home timeline
def fetch_timeline_tweets
    p "fetch from twitter"

    twitter_client = Twitter::REST::Client.new do |config|
        config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
        config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
        config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
        config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
    end

    return twitter_client.home_timeline(count: 3200, include_rts: true).map(&:attrs)
end

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

def save_to_redis(tweets, redis)
    prefix = 'tweets'

    # Ignore already saved tweets
    # Using tweet ID to check existence
    recent_saved_ids = redis.lrange("#{prefix}:id", 0, 4) # NOTE: I think 5 is enough
    stop_idx = tweets.find { |t| recent_saved_ids.include?(t[:id]) }
    tweets = tweets[0...stop_idx]

    tweets = tweets.reverse # Storing from older one
    tweets.each do |attr|
        attr.each_pair do |key,val|
            redis.lpush("#{prefix}:#{key}", val)
        end
    end
end

if $0 == __FILE__
    opt_parser = OptionParser.new
    opt_parser.on('-t', '--test')
    opt_parser.on('-s JSON', '--serialize=JSON') { |v| Pathname.new(v) }
    options = {}
    opt_parser.parse!(into: options)

    if options.include?(:test)
        require 'dotenv'
        Dotenv.load
    end

    json_path = options.fetch(:serialize, nil)
    tweets = JSON.parse(json_path.read, symbolize_names: true) if json_path&.file?
    tweets ||= fetch_timeline_tweets
    p tweets.size
    JSON.dump(tweets, json_path)

    begin
        shrinked = tweets.map { |t| shrink_tweet(t) }
        redis = Redis.new(url: ENV['REDIS_URL'])
        save_to_redis(shrinked, redis)
    rescue => err
        p err
        raise
    end
end
