require "net/http"
require "uri"

SONG_URL_DOMAINS = %w[
  song.link
  album.link
  youtube.com
  youtu.be
  music.apple.com
  open.spotify.com
]

def share_media_link_to_slack(tweets, slack_webhook_url, logger: nil)
  # slack API
  uri = URI.parse(slack_webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  post_to_slack = Proc.new do |text|
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req.body = {
      text: text,
    }.to_json
  end

  tweets.each do |t|
    urls = t.attrs[:entities][:urls]&.filter { |url| SONG_URL_DOMAINS.any? { |dom| url[:expanded_url].include?(dom) } }
    unless urls.empty?
      # tweet URL
      post_to_slack.call(t.url)

      # song URL
      urls.each { |url| post_to_slack.call(url[:expanded_url]) }
    end
  end
end
