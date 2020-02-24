# share links to media to slack channel

require "twitter"
require "net/http"
require "uri"

# @param tweets [Array<Twitter::Tweets>] tweets to process
# @param slack_webhook_url String Slack webhook URL
def medialink_pipeline(tweets, slack_webhook_url, logger: nil)
  uri = URI.parse(slack_webhook_url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  post_to_slack = Proc.new do |hash|
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req.body = hash.to_json
    http.request(req)
  end

  # traverse from old ones
  tweets.reverse.each do |t|
    urls = t.attrs[:entities][:urls]
    next if urls.empty?

    urls.filter! { |url| SONG_URL_DOMAINS.include?(URI.parse(url).host) }

    # tweet
    post_to_slack.call({
      attachments: [
        {
          title: "#{t.attrs[:user][:name]} (@#{t.attrs[:user][:screen_name]})",
          title_link: t.url,
          text: t.attrs[:text],
          thumb_url: t.attrs[:user][:profile_image_url_https],
          footer: t.attrs[:created_at],
        },
      ],
    })

    # song link
    # TODO: expand apple music
    urls.each do |url|
      post_to_slack.call({
        text: url[:expanded_url],
      })
    end
  end
end

SONG_URL_DOMAINS = %w[
  song.link
  album.link
  youtube.com
  youtu.be
  music.apple.com
  open.spotify.com
]
