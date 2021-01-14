require "json"
require "pathname"
require "optparse"
require "logger"

require "redis"

require_relative "lib/twitter_util"
require_relative "lib/slack_util"

require_relative "pipeline/frequency"
require_relative "pipeline/mediainfo"

def main
  pipeline_name, options = parse_args(ARGV)

  if options[:test]
    require "dotenv"
    Dotenv.load
  end

  logger = Logger.new($stderr, progname: "TweetCurator")

  twitter_client = create_twitter_client
  redis = create_redis_client
  webhook = create_slack_webhook

  json = Pathname.new(options[:serialize]) if options[:serialize]
  if json&.file?
    tweets = JSON.parse(json.read, symbolize_names: true)
  else
    if !options[:ids].empty?
      tweets = options[:ids].map { |id| twitter_client.status(id.to_i, tweet_mode: "extended") }
    else
      since_id = redis&.get("since_id")
      tweets = twitter_client.home_timeline(since_id: since_id, tweet_mode: "extended")
      redis&.set("since_id", tweets.first&.[](:attrs)[:id])
    end
    json&.write(tweets.to_json)
  end

  case pipeline_name
  when "mediainfo"
    call_without_abort(logger: logger) { mediainfo_pipeline(tweets, slack_webhook: webhook, odesli_api_key: ENV["ODESLI_API_KEY"]) }
  when "frequency"
    call_without_abort(logger: logger) { frequency_pipeline(tweets, redis: redis) }
  else
    raise "No such pipeline: #{pipeline_name}"
  end
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

def parse_args(args)
  options = { ids: [] }
  opt_parser = OptionParser.new do |p|
    p.banner = "usage: #{File.basename($0)} [options] pipeline_name"
    p.on("-t", "--test", "use local dotenv config")
    p.on("-s JSON", "--serialize=JSON",
         "if exists, deserialize tweets from file; otherwise serialize tweets to file")
    p.on("-i TWEET_ID", "--id=TWEET_ID",
         "tweet id to fetch instead of timeline; can be specified multiple times") do |id|
      options[:ids] << Integer(id.to_i)
    end
  end
  opt_parser.parse!(args, into: options)

  pipeline_name = args.pop
  raise "No pipiline name specified" unless pipeline_name

  [pipeline_name, options]
end

def create_twitter_client
  TwitterUtil::Client.new(
    consumer_key: ENV.fetch("TWITTER_CONSUMER_KEY"),
    consumer_secret: ENV.fetch("TWITTER_CONSUMER_SECRET"),
    access_token: ENV.fetch("TWITTER_ACCESS_TOKEN"),
    access_token_secret: ENV.fetch("TWITTER_ACCESS_TOKEN_SECRET"),
  )
end

def create_redis_client
  Redis.new(url: ENV.fetch("REDIS_URL"))
end

def create_slack_webhook
  SlackUtil::Webhook.new(ENV.fetch("SLACK_WEBHOOK_URL"))
end

if $0 == __FILE__
  main
end
