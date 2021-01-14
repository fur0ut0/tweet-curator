require "net/http"
require "uri"
require "json"

module API
  def self.call(url, params)
    params = URI.encode_www_form(params)
    uri = URI.parse(url + "?#{params}")
    http = Net::HTTP.new(uri.host, uri.port)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      request = Net::HTTP::Get.new(uri)
      http.request(request)
    end
    response.value # 例外を発生させる
    JSON.parse(response.body)
  end
end
