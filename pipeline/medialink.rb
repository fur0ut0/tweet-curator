# share links to media to slack channel

require "net/http"
require "time"
require "uri"
require "open-uri"

require "twitter"

require_relative "../lib/slack_util"

# @param tweets [Array<Hash>] tweets to process
# @param slack_webhook_url String Slack webhook URL
def medialink_pipeline(tweets, slack_webhook:)
  # traverse from old ones
  tweets.reverse.each do |t|
    urls = t[:attrs][:entities][:urls].map { |url| url[:expanded_url] }.uniq
    is_nowplaying = !!(/nowplaying/i =~ t[:attrs][:text])
    next if urls.empty? && !is_nowplaying

    # generate attachment data structure of each service
    main_text_parts, sub_texts, attachments = gen_medialink_structure(urls)
    main_text_parts.prepend("Now Playing") if is_nowplaying
    next if main_text_parts.empty?

    attachments.prepend(gen_twitter_attachment(t))

    slack_webhook.post({
      text: "*#{main_text_parts.join(", ")}*",
      attachments: attachments,
    })

    sub_texts.each do |text|
      slack_webhook.post({
        text: text,
        unfurl_links: true,
      })
    end
  end
end

def gen_twitter_attachment(tweet)
  attrs = tweet[:attrs].fetch(:retweeted_status, tweet[:attrs])

  gen_name = Proc.new do |attrs|
    "#{attrs[:user][:name]} (@#{attrs[:user][:screen_name]}) #{attrs[:user][:protected] ? "🔒" : ""}"
  end

  attachment = {
    author_name: gen_name.call(attrs),
    author_link: tweet[:url],
    author_icon: attrs[:user][:profile_image_url_https],
    color: "#00acee",
    text: attrs[:text],
    ts: Time.parse(attrs[:created_at]).to_i,
  }
  if tweet[:attrs][:retweeted_status]
    attachment[:footer] = "Retweeted by #{gen_name.call(tweet[:attrs])}"
    attachment[:footer_icon] = tweet[:attrs][:user][:profile_image_url_https]
  end
  if attrs[:entities][:media]
    attachment[:thumb_url] = attrs[:entities][:media].first[:media_url_https]
  end
  attachment
end

def gen_medialink_structure(urls)
  main_text_parts = []
  sub_texts = []
  attachments = []
  urls.each do |url|
    host = URI.parse(url).host
    case host
    when "song.link", "album.link"
      main_text_parts << "Odesli"
      #attachments << gen_odesli_attachment(url)
      sub_texts << url
    when "youtube.com", "youtu.be"
      main_text_parts << "Youtube"
      sub_texts << url
    when "music.apple.com"
      main_text_parts << "Apple Music"
      #attachments << gen_apple_music_attachment(url)
      sub_texts << url
    when "open.spotify.com"
      main_text_parts << "Spotify"
      sub_texts << url
    end
  end.compact
  [main_text_parts, sub_texts, attachments]
end
