# frozen_string_literal: true

require 'json'
require 'pathname'

require_relative 'util'

module TweetCurator
   # serialize/deserialize tweets json
   class TweetSerializer
      def initialize(fname, logger:)
         @fname = Pathname.new(fname)
         @logger = logger
      end

      def exists?
         @fname.file?
      end

      def serialize(tweets, overwrite: false)
         return if exists? && !overwrite

         @logger.info(self.class.name) { "serialize #{tweets.size} tweets to #{@fname}" }
         @fname.write(tweets.to_json)
      end

      def deserialize(ignore_empty: true)
         return nil if !exists? && ignore_empty

         @logger.info(self.class.name) { "deserialize tweets from #{@fname}" }
         Util.parse_json_str(@fname.read).tap do |tweets|
            @logger.info(self.class.name) { "deserialized #{tweets.size} tweets" }
            @logger.debug(self.class.name) { tweets }
         end
      end
   end
end
