# share links to media to slack channel

require "net/http"
require "time"
require "uri"

require "twitter"
require "nokogiri"

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
    urls = t.attrs[:entities][:urls].uniq
    next if urls.empty?

    # generate attachment data structure of each service
    title_parts = []
    attachments = urls.map do |url|
      case URI.parse(url).host
      when Regexp.escape("song.link"), Regexp.escape("album.link")
        title_parts << "Odesli"
        gen_odesli_attachment(url)
      when Regexp.escape("youtube.com"), Regexp.escape("youtu.be")
        title_parts << "Youtube"
        gen_youtube_attachment(url)
      when Regexp.escape("music.apple.com")
        title_parts << "Apple Music"
        gen_apple_music_attachment(url)
      when Regexp.escape("open.spotify.com")
        title_parts << "Spotify"
        gen_spotify_attachment(url)
      else
        nil
      end
    end.compact
    next if attachments.empty?

    attachments.prepend(gen_twitter_attachment(t))

    post_to_slack.call({
      title: title_parts.join(","),
      attachments: attachments,
    })
  end
end

def gen_twitter_attachment(tweet)
  attrs = tweet.attrs.fetch(:retweeted_status)
  attrs ||= tweet.attrs

  gen_name = Proc.new do |attrs|
    "#{attrs[:user][:name]} (@#{attrs[:user][:screen_name]})"
  end

  attachment = {
    title: gen_name(attrs),
    title_link: tweet.url,
    text: attrs[:text],
    thumb_url: attrs[:user][:profile_image_url_https],
    ts: Time.parse(attrs[:created_at]).to_i,
  }
  if tweet.attrs.include?(:retweeted_status)
    attachment[:footer] = "Retweeted by #{gen_name(tweet.attrs)}"
  end
  attachment
end

def fetch_html(url)
  URI.open(URI.encode(url), ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |f|
    return Nokogiri::HTML.parse(f)
  end
end

def gen_spotify_attachment(url)
  {
    pretext: url,
  }
end

def gen_apple_music_attachment(url)
  {
    pretext: url,
  }
end

def gen_odesli_attachment(url)
  {
    pretext: url,
  }
end

def gen_youtube_attachment(url)
  {
    pretext: url,
  }
end
