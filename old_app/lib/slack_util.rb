require "net/http"
require "uri"
require "open-uri"

module SlackUtil
  class Webhook
    def initialize(url)
      @uri = URI.parse(url)
      @http = Net::HTTP.new(@uri.host, @uri.port)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    def post(data)
      req = Net::HTTP::Post.new(@uri.request_uri)
      req["Content-Type"] = "application/json"
      req.body = data.to_json
      @http.request(req)
    end
  end
end
