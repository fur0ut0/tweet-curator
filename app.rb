# frozen_string_literal: true

require 'logger'
require 'optparse'

require_relative 'tweet_curator/media_task'
require_relative 'tweet_curator/tweet_fetcher'
require_relative 'tweet_curator/env_fetcher'

# main application
class App
   TASKS = %i[media].freeze

   def initialize(args)
      @task_name, @options = parse_args(args)

      env_fetcher.load_dotenv if @options[:dotenv]
   end

   def run
      tweet_fetcher
      task
   end

   private

   OPT_PARSER = OptionParser.new do |p|
      p.banner = "usage: #{File.basename($PROGRAM_NAME)} [OPTIONS] TASK_NAME TASK_ARGS"
      p.on('--dotenv', 'use local dotenv config')
      p.on('-H', '--home', 'fetch home timeline (default behavior)')
      p.on('-I TWEET_ID', '--tweet_id=TWEET_ID', 'fetch specifed tweet ID')
      p.on('-L LIST_ID', '--list_id=LIST_ID', 'fetch specified list ID')
      p.on('-J JSON', '--json=JSON',
           'if exists, deserialize tweets from file; otherwise serialize tweets to file')
      p.on('-i INIT_ARG', '--init_arg=INIT_ARG', 'argument for task initialization')
      p.on('-r RUN_ARG', '--run_arg=RUN_ARG', 'argument for task running')
   end.freeze

   def parse_args(args)
      options = {}
      task_args = OPT_PARSER.parse(args, into: options)

      task_name = task_args.pop&.to_sym
      raise 'no task name specified' unless task_name
      raise "invalid task name: #{task_name}" unless TASKS.include?(task_name)

      fetch_mode = %i[home tweet_id list_id].filter { |k| options.key?(k) }
      raise "multiple tweet fetching mode specified: #{fetch_mode.join(', ')}" if fetch_mode.size > 1

      [task_name, options]
   end

   def env_fetcher
      @env_fetcher ||= TweetCurator::EnvFetcher.new
      @env_fetcher
   end

   def tweet_fetcher
      @tweet_fetcher ||= TweetCurator::TweetFetcher.new(
         consumer_key: env_fetcher.fetch(:TWITTER_CONSUMER_KEY),
         consumer_secret: env_fetcher.fetch(:TWITTER_CONSUMER_SECRET),
         access_token: env_fetcher.fetch(:TWITTER_ACCESS_TOKEN),
         access_token_secret: env_fetcher.fetch(:TWITTER_ACCESS_TOKEN_SECRET)
      )
      @tweet_fetcher
   end

   def task
      unless @task
         case @task_name
         when :media
            @task = TweetCurator::MediaTask.new(@options[:init_arg],
                                                slack_webhook_url: env_fetcher.fetch(:SLACK_WEBHOOK_URL),
                                                odesli_api_key: env_fetcher.get(:ODESLI_API_KEY))
         end
      end
      @task
   end
end

App.new(ARGV).run if $PROGRAM_NAME == __FILE__
