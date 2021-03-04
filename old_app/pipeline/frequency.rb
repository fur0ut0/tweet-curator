# aggregate tweet frequency of users

require "redis"
require "time"

def frequency_pipeline(tweets, redis:, logger: nil)
  min_tweets = tweets.map { |t| Frequency::MinTweet.from_tweet(t[:attrs]) }
  redis = Frequency::MinTweetRedis.new(redis)

  recent_ids = redis.restore(0...5, use_keys: [:id]).map(&:id)
  stop_idx = min_tweets.find_index { |t| recent_ids.include?(t.id) }
  min_tweets = min_tweets[0...stop_idx]

  min_tweets.reverse.each { |t| redis.store(t) }
  logger&.info { "Stored #{min_tweets.size} tweets in Redis" }
end

module Frequency
  class MinTweet
    FIELDS = %i[id time screen_name type]
    attr_reader *FIELDS

    def initialize(id: nil, time: nil, screen_name: nil, type: nil)
      @id = id ? id.to_i : -1
      @time = time ? Time.parse(time) : Time.now
      @screen_name = screen_name || "unknown"
      @type = type || "unknown"
    end

    def self.from_tweet(tweet)
      determine_type = ->(tweet) {
        return "retweet" if tweet[:retweeted_status]
        return "reply" if tweet[:in_reply_to_status_id]
        return "quoted" if tweet[:quoted_status]
        return "normal"
      }

      hash = {
        id: tweet[:id],
        time: tweet[:created_at],
        screen_name: tweet[:user][:screen_name],
        type: determine_type.call(tweet),
      }

      new(hash)
    end

    def [](key)
      instance_variable_get("@#{key}")
    end

    def to_h
      FIELDS.map { |key| [key, instance_variable_get("@#{key}")] }.to_h
    end
  end

  class MinTweetRedis
    def initialize(redis, prefix: "min_tweets")
      @redis = redis
      @prefix = prefix
    end

    def store(min_tweet)
      MinTweet::FIELDS.each do |key|
        @redis.lpush("#{@prefix}:#{key}", min_tweet[key])
      end
    end

    def restore(idx_range, use_keys: MinTweet::FIELDS)
      start_idx = idx_range.first

      raise "idx_range must be integer range" unless start_idx.is_a?(Integer)
      raise "use_keys must have at least one key" if use_keys.empty?

      def get_stop_idx(range)
        last = range.last
        return -1 if last.nil?
        return last - 1 if range.exclude_end?
        return last
      end

      stop_idx = get_stop_idx(idx_range)

      values_per_key = MinTweet::FIELDS.map do |key|
        if use_keys.include?(key)
          @redis.lrange("#{@prefix}:#{key}", start_idx, stop_idx)
        else
          nil
        end
      end

      n_items = values_per_key.compact.first.size
      values_per_key.map! do |elm|
        elm.nil? ? [nil] * n_items : elm
      end
      items = values_per_key.transpose

      items.map do |item|
        hash = MinTweet::FIELDS.zip(item).to_h
        MinTweet.new(hash)
      end
    end
  end
end
