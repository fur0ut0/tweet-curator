# share links to media to slack channel

require "net/http"
require "time"
require "uri"
require "open-uri"

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
    urls = t.attrs[:entities][:urls].map { |url| url[:expanded_url] }.uniq
    next if urls.empty?

    # generate attachment data structure of each service
    main_text_parts, sub_texts, attachments = gen_medialink_structure(urls)
    next if main_text_parts.empty?

    attachments.prepend(gen_twitter_attachment(t))

    post_to_slack.call({
      text: "*#{main_text_parts.join(", ")}*",
      attachments: attachments,
    })

    sub_texts.each do |text|
      post_to_slack.call({
        text: text,
        unfurl_links: true,
      })
    end
  end
end

def gen_twitter_attachment(tweet)
  attrs = tweet.attrs.fetch(:retweeted_status, tweet.attrs)

  gen_name = Proc.new do |attrs|
    "#{attrs[:user][:name]} (@#{attrs[:user][:screen_name]})"
  end

  attachment = {
    title: gen_name.call(attrs),
    title_link: tweet.url,
    color: "#00acee",
    text: attrs[:text],
    thumb_url: attrs[:user][:profile_image_url_https],
    ts: Time.parse(attrs[:created_at]).to_i,
  }
  if tweet.attrs.include?(:retweeted_status)
    attachment[:footer] = "Retweeted by #{gen_name.call(tweet.attrs)}"
    attachment[:footer_icon] = tweet.attrs[:user][:profile_image_url_https]
  end
  attachment
end

def fetch_html(url)
  URI.open(URI.encode(url), ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE) do |f|
    return Nokogiri::HTML.parse(f)
  end
end

def gen_medialink_structure(urls)
  main_text_parts = []
  sub_texts = []
  attachments = []
  urls.each do |url|
    host = URI.parse(url).host
    case host
    when /song\.link/, /"album\.link"/
      main_text_parts << "Odesli"
      #attachments << gen_odesli_attachment(url)
      sub_texts << url
    when /youtube\.com/, /youtu\.be/
      main_text_parts << "Youtube"
      sub_texts << url
    when /music\.apple\.com/
      main_text_parts << "Apple Music"
      #attachments << gen_apple_music_attachment(url)
      sub_texts << url
    when /open\.spotify\.com/
      main_text_parts << "Spotify"
      sub_texts << url
    end
  end.compact
  [main_text_parts, sub_texts, attachments]
end

def gen_apple_music_attachment(url)
  # TODO
end

def gen_odesli_attachment(url)
  # TODO
end
