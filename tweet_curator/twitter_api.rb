# frozen_string_literal: true

require 'oauth'
require 'logger'
require 'uri'

module TweetCurator
   # Twitter API
   class TwitterAPI
      BASE_URL = 'https://api.twitter.com'
      VERSION = '1.1'

      def initialize(consumer_key:, consumer_secret:, access_token:, access_token_secret:, logger:)
         @consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: BASE_URL)
         @token = OAuth::AccessToken.new(@consumer, access_token, access_token_secret)
         @logger = logger
      end

      def get(entrypoint, params = {})
         entrypoint = "/#{entrypoint}" if entrypoint[0] != '/'
         url = "#{BASE_URL}/#{VERSION}#{entrypoint}#{params.empty? ? '' : "?#{URI.encode_www_form(params)}"}"

         @logger.info(self.class.name) { %(get "#{url}") }
         response = @token.get(url)

         response.value
         response.body
      end
   end
end
