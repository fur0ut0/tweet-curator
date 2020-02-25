require "json"
require "pathname"
require "optparse"
require "logger"

require "twitter"
require "redis"

require_relative "lib/twitter_util"

require_relative "pipeline/frequency"
require_relative "pipeline/medialink"

def main
  pipeline_name, options = parse_args(ARGV)

  if options[:test]
    require "dotenv"
    Dotenv.load
  end

  logger = Logger.new($stderr, progname: "TweetCurator")

  twitter_client = TwitterUtil.create_rest_client({
    consumer_key: ENV["TWITTER_CONSUMER_KEY"],
    consumer_secret: ENV["TWITTER_CONSUMER_SECRET"],
    access_token: ENV["TWITTER_ACCESS_TOKEN"],
    access_token_secret: ENV["TWITTER_ACCESS_TOKEN_SECRET"],
  })

  redis = Redis.new(url: ENV["REDIS_URL"])
  webhook = SlackUtil::Webhook.new(ENV["SLACK_WEBHOOK_URL"])

  json = Pathname.new(options[:serialize]) if options[:serialize]
  if json&.file?
    tweets = JSON.parse(json.read)
  else
    since_id = redis&.get("since_id")
    tweets = TwitterUtil.fetch_timeline(twitter_client, since_id).map(&:to_h)
    redis&.set("since_id", tweets.first&.[](:attrs)[:id])
    json&.write(tweets.to_json)
  end

  case pipeline_name
  when "medialink"
    call_without_abort(logger: logger) { medialink_pipeline(tweets, slack_webhook: webhook) }
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
  options = {}
  opt_parser = OptionParser.new do |p|
    p.banner = "usage: #{File.basename($0)} [options] pipeline_name"
    p.on("-t", "--test", "use local dotenv config")
    p.on("-s JSON", "--serialize=JSON", "if exists, deserialize tweets from file; otherwise serialize tweets to file")
  end
  opt_parser.parse!(args, into: options)

  pipeline_name = args.pop
  raise "No pipiline name specified" unless pipeline_name

  [pipeline_name, options]
end

if $0 == __FILE__
  main
end
