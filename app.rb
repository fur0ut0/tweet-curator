# frozen_string_literal: true

require 'logger'
require 'optparse'

require_relative 'tweet_curator/media_task'
require_relative 'tweet_curator/tweet_fetcher'
require_relative 'tweet_curator/env_fetcher'

# main application
class App
   TASKS = {
      media: TweetCurator::MediaTask
   }.freeze

   def initialize(args)
      task_name, task_args, @options = parse_args(args)
      task_klass = TASKS.fetch(task_name) { |k| raise "invalid task name: #{k}" }

      @env_fetcher = TweetCurator::EnvFetcher.new
      @env_fetcher.load_dotenv if @options[:dotenv]

      @task = task_klass.new(task_args, @env_fetcher)

      @tweet_fetcher = TweetCurator::TweetFetcher.new(@env_fetcher)
   end

   def run
      # TODO
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
   end.freeze

   def parse_args(args)
      options = {}
      task_args = OPT_PARSER.parse(args, into: options)

      task_name = task_args.pop&.to_sym
      raise 'No task name specified' unless task_name

      fetch_mode = %i[home tweet_id list_id].filter { |k| options.key?(k) }
      raise "multiple tweet fetching mode specified: #{fetch_mode.join(', ')}" if fetch_mode.size > 1

      [task_name, task_args, options]
   end
end

App.new(ARGV).run if $PROGRAM_NAME == __FILE__
