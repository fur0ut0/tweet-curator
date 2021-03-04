# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module TweetCurator
   # Common utility
   module Util
      class << self
         def get_tweet_url(screen_name, tweet_id)
            "https://twitter.com/#{screen_name}/status/#{tweet_id}"
         end

         def parse_json_str(str)
            JSON.parse(str, symbolize_names: true)
         end

         def get_api(url, params = {})
            uri = URI.parse("#{url}#{params.empty? ? '' : "?#{URI.encode_www_form(params)}"}")
            response = Net::HTTP.start(uri.host, uri.port,
                                       use_ssl: true,
                                       verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
               request = Net::HTTP::Get.new(uri)
               http.request(request)
            end
            response.value
            response.body
         end

         def post_api(url, data)
            uri = URI.parse(url)
            response = Net::HTTP.start(uri.host, uri.port,
                                       use_ssl: true,
                                       verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
               request = Net::HTTP::Post.new(uri.request_uri)
               request['Content-Type'] = 'application/json'
               request.body = data.to_json
               http.request(request)
            end
            response.value
            response.body
         end
      end
   end
end
