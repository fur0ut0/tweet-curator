require "pathname"
require "optparse"
require "logger"

require "twitter"
require "redis"

require_relative "lib/frequency"
require_relative "lib/songlink"

# Fetch twitter home timeline
def fetch_timeline_tweets(twitter_client, since_id = nil)
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

def main
  options = {}
  opt_parser = OptionParser.new
  opt_parser.on("-t", "--test", "use local dotenv config")
  opt_parser.parse!(into: options)

  if options[:test]
    require "dotenv"
    Dotenv.load
  end

  logger = Logger.new($stderr, progname: "TweetCurator")

  twitter_client = Twitter::REST::Client.new do |config|
    config.consumer_key = ENV["TWITTER_CONSUMER_KEY"]
    config.consumer_secret = ENV["TWITTER_CONSUMER_SECRET"]
    config.access_token = ENV["TWITTER_ACCESS_TOKEN"]
    config.access_token_secret = ENV["TWITTER_ACCESS_TOKEN_SECRET"]
  end

  # fetch timeline using API
  redis = Redis.new(url: ENV["REDIS_URL"]) if ENV.include?("REDIS_URL")
  since_id = redis&.get("since_id")
  tweets = fetch_timeline_tweets(twitter_client, since_id)
  redis&.set("since_id", tweets.first&.attrs[:id])

  # pipelines
  if ENV.include?("SLACK_WEBHOOK_URL")
    call_without_abort(logger: logger) do share_media_link_to_slack(tweets, ENV["SLACK_WEBHOOK_URL"]) end
  end
end

if $0 == __FILE__
  main
end
