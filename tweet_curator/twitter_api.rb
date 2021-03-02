# frozen_string_literal: true

require 'oauth'

module TweetCurator
   # Twitter API
   class TwitterAPI
      BASE_URL = 'https://api.twitter.com'
      VERSION = '1.1'

      def initialize(consumer_key:, consumer_secret:, access_token:, access_token_secret:)
         @consumer = OAuth::Consumer.new(consumer_key, consumer_secret, site: BASE_URL)
         @token = OAuth::AccessToken.new(@consumer, access_token, access_token_secret)
      end

      def get(entrypoint, params = {})
         url = "#{BASE_URL}/#{VERSION}#{entrypoint}#{unless params.empty?
                                                        "?#{params.sort.to_h.map do |k, v|
                                                               "#{k}=#{v}"
                                                            end.join('&')}"
                                                     end}"
         @token.get(url)
      end
   end
end
