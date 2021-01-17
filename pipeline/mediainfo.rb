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

    attachments = [gen_twitter_attachment(tweet)]

    slack_webhook.post({
      text: "*#{info.types.join(", ")}*",
      attachments: attachments,
    })

    info.links.each do |link|
      slack_webhook.post({
        text: link,
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
  attr_reader :types, :links

  ODESLI_API = "https://api.song.link/v1-alpha.1/links"

  # @param tweet [Hash] hased tweet data
  def initialize(tweet, odesli_api_key)
    @odesli_api_key = odesli_api_key

    @types = []
    @links = []

    @types << "Now playing" if /nowplaying/i =~ (tweet[:attrs][:full_text] || tweet[:attrs][:text])

    urls = tweet[:attrs][:entities][:urls].uniq { |url| url[:expanded_url] }
    urls.each do |url|
      case URI.parse(url[:expanded_url]).host
      when "youtube.com", "youtu.be"
        @types << "Youtube"
        @links << url[:expanded_url]
      when "nicovideo.jp"
        @types << "NicoNico"
        @links << url[:expanded_url]
      when "song.link", "album.link", "odesli.co"
        @types << "Odesli"
        src = url[:expanded_url]
        if sub = get_apple_music_url(src)
          src += " => " + sub
        end
        @links << src
      when /.*music\.apple\.com/
        @types << "Apple Music"
        @links << url[:expanded_url]
      when "open.spotify.com"
        @types << "Spotify"
        src = url[:expanded_url]
        if sub = get_apple_music_url(src)
          src += " => " + sub
        end
        @links << src
      when "music.amazon.co.jp"
        @types << "Amazon Music"
        src = url[:expanded_url]
        if sub = get_apple_music_url(src)
          src += " => " + sub
        end
        @links << src
      when "music.line.me"
        @types << "LINE MUSIC"
        @links << url[:expanded_url]
      when "lnk.to"
        @types << "linkfire"
        @links << url[:expanded_url]
      when "linkco.re"
        @types << "LinkCore"
        @links << url[:expanded_url]
      when /.*\.hatenablog\.com/
        @types << "Hatena blog"
        @links << url[:expanded_url]
      when "anond.hatelabo.jp"
        @types << "Hatelabo AnonymousDiary"
        @links << url[:expanded_url]
      when "note.com"
        @types << "note"
        @links << url[:expanded_url]
      end
    end
  end

  def mediainfo?; !@types.empty?; end

  private

  def get_apple_music_url(media_url)
    params = {
      key: @odesli_api_key,
      url: media_url,
      userCountry: "JP",
    }

    retry_count = 3
    begin
      result = API.call(ODESLI_API, params)
    rescue HTTPRetriableError => e
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
