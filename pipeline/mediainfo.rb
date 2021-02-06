# share links to media to slack channel

require "time"

require_relative "../lib/slack_util"
require_relative "../lib/api"

# @param tweets [Array<Hash>] tweets to process
# @param slack_webhook [SlackUtil::Webhook] Slack webhook URL
def mediainfo_pipeline(tweets, slack_webhook:, odesli_api_key:)
  # traverse from old ones
  tweets.reverse.each do |tweet|
    info = Mediainfo.new(tweet, odesli_api_key)
    next unless info.mediainfo?

    slack_webhook.post({
      text: info.links.join("
"),
      unfurl_links: true,
      attachments: [gen_slack_attachment(tweet)],
    })
  end
end

def gen_slack_attachment(tweet)
  attrs = tweet[:attrs].fetch(:retweeted_status, tweet[:attrs])

  gen_name = Proc.new do |attrs|
    "#{attrs[:user][:name]} (@#{attrs[:user][:screen_name]}) #{attrs[:user][:protected] ? "🔒" : ""}"
  end

  attachment = {
    author_name: gen_name.call(attrs),
    author_link: tweet[:url],
    author_icon: attrs[:user][:profile_image_url_https],
    color: "#00acee",
    text: attrs[:full_text] || attrs[:text],
    ts: Time.parse(attrs[:created_at]).to_i,
    mrkdwn_in: [],
  }
  if tweet[:attrs][:retweeted_status]
    attachment[:footer] = "Retweeted by #{gen_name.call(tweet[:attrs])}"
    attachment[:footer_icon] = tweet[:attrs][:user][:profile_image_url_https]
  end
  if attrs[:entities][:media]
    url = attrs[:entities][:media].first[:media_url_https]
    # Use resized image because the thumbnail won't show up if an image is too large
    url += "?name=thumb" if URI.parse(url).host == "pbs.twimg.com"
    attachment[:thumb_url] = url
  end
  attachment
end

class Mediainfo
  attr_reader :links

  ODESLI_API = "https://api.song.link/v1-alpha.1/links"

  # @param tweet [Hash] hased tweet data
  def initialize(tweet, odesli_api_key)
    @odesli_api_key = odesli_api_key

    @is_media = false

    @links = []

    @is_media = true if /nowplaying/i =~ (tweet[:attrs][:full_text] || tweet[:attrs][:text])

    # Twitter video
    if mp4_url = get_mp4_url(tweet)
      @is_media = true
      @links << mp4_url
    end

    urls = tweet[:attrs][:entities][:urls].map { |url| url[:expanded_url] }
    @is_media = true unless urls.empty?
    urls.map! do |url|
      case URI.parse(url).host
      when "song.link", "album.link", "open.spotify.com", "music.amazon.co.jp"
        # convert into Apple Music link
        if sub = get_apple_music_url(url)
          url += " => " + sub
        end
      end
      url
    end

    @links.concat(urls)
  end

  def mediainfo?; @is_media; end

  private

  def get_mp4_url(tweet)
    extended_entities = tweet[:attrs][:extended_entities]
    return nil unless extended_entities

    media = extended_entities[:media]
    return nil unless media && !media.empty?

    video_info = media.first[:video_info]
    return nil unless video_info

    variants = video_info[:variants]
    return nil unless variants

    mp4 = variants.filter { |x| x[:content_type] =~ /mp4/ }
                  .sort_by { |x| x[:bitrate] }
                  .last
    return nil if mp4.empty?

    mp4[:url]
  end

  def get_apple_music_url(media_url)
    params = {
      key: @odesli_api_key,
      url: media_url,
      userCountry: "JP",
    }

    retry_count = 3
    begin
      result = API.call(ODESLI_API, params)
    rescue Net::HTTPRetriableError => e
      return nil if retry_count <= 0
      retry_count -= 1
      retry
    rescue => e
      return nil
    end

    links = result["linksByPlatform"]
    return nil unless links

    a = links["appleMusic"]
    return a["url"] if a

    i = links["itunes"]
    return i["url"] if i

    nil
  end
end
