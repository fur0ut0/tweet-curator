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

  post_to_slack = Proc.new do |hash|
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req.body = hash.to_json
    http.request(req)
  end

  # traverse from old ones
  tweets.reverse.each do |t|
    # collect song link
    urls = t.attrs[:entities][:urls]&.filter do |url|
      SONG_URL_DOMAINS.any? { |dom| url[:expanded_url].include?(dom) }
    end

    next if urls.empty?

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
