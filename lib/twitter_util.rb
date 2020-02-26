require "oauth"
require "json"

module TwitterUtil
  module Timeline
    MAX_AVAILABLE = 800
    MAX_PER_REQUEST = 200
  end

  class Client
    API_BASE_URL = "https://api.twitter.com"
    API_VERSION = "1.1"

    def initialize(consumer_key:, consumer_secret:,
                   access_token:, access_token_secret:)
      @consumer = OAuth::Consumer.new(consumer_key, consumer_secret,
                                      site: API_BASE_URL)
      @token = OAuth::AccessToken.new(@consumer, access_token, access_token_secret)
    end

    def home_timeline(options = {})
      since_id = Integer(options[:since_id])
      max_id = nil
      total_tweets = []

      (Timeline::MAX_AVAILABLE / Timeline::MAX_PER_REQUEST).ceil.times do |i|
        params = {
          count: Timeline::MAX_PER_REQUEST,
          include_rts: true,
        }
        params[:max_id] = max_id if max_id
        params[:since_id] = since_id if since_id
        params[:tweet_mode] = options[:tweet_mode] if options[:tweet_mode]
        response = get("/statuses/home_timeline.json", params)

        tweets = parse(response)
        break if tweets.empty?

        tweets.map! { |t| compose(t) }
        last_id = tweets.last[:attrs][:id]
        tweets.shift if max_id
        max_id = last_id

        total_tweets += tweets
        break if tweets.size < Timeline::MAX_PER_REQUEST
      end

      total_tweets
    end

    def status(id, options = {})
      params = { id: id }
      params[:tweet_mode] = options[:tweet_mode] if options[:tweet_mode]
      response = get("/statuses/show.json", params)
      tweet = parse(response)
      compose(tweet)
    end

    private

    def get(entrypoint, params = {})
      url = "#{API_BASE_URL}/#{API_VERSION}" + entrypoint
      url += "?" + Hash[params.sort].map { |k, v| "#{k}=#{v}" }.join("&") unless params.empty?
      @token.get(url)
    end

    def parse(response)
      JSON.parse(response.body, symbolize_names: true)
    end

    def compose(tweet)
      url = "https://twitter.com/#{tweet[:user][:screen_name]}/status/#{tweet[:id]}"
      {
        attrs: tweet,
        url: url,
      }
    end
  end
end
