# frozen_string_literal: true

require 'time'

require_relative 'util'

module TweetCurator
   # MediaTask utility
   module MediaUtil
      ODESLI_API_URL = 'https://api.song.link/v1-alpha.1/links'

      IMAGE_HOST = %w[pbs.twimg.com].freeze

      GENERAL_MUSIC_HOST = %w[linkco.re big-up.style nowplaying.jp orcd.co streamlink.to].freeze
      GENERAL_MUSIC_HOST_RE = [/soundcloud/, /lnk\.to/].freeze

      CONVERTIBLE_MUSIC_HOST = %w[song.link album.link open.spotify.com music.amazon.co.jp].freeze
      CONVERTIBLE_MUSIC_HOST_RE = [/music\.apple\.com/].freeze

      VIDEO_HOST = %w[youtu.be youtube.com nico.ms nicovideo.jp video.twimg.com].freeze

      class << self
         def get_odesli_info(url, key: nil)
            params = {
               url: url,
               userCountry: 'JP',
            }
            params[:key] = key if key
            begin
               Util.parse_json_str(Util.get_api(ODESLI_API_URL, params))
            rescue Net::HTTPRetriableError
               retry
            rescue Error
               nil
            end
         end

         def get_mp4_url(tweet)
            tweet.fetch(:extended_entities, {})
                 .fetch(:media, [{}]).first
                 .fetch(:video_info, {})
                 .fetch(:variants, [])
                 .filter { |x| x[:content_type] =~ /mp4/ }
                 .max_by { |x| x[:bitrate] }
            &.fetch(:url, nil)
         end

         def get_image_urls(tweet)
            tweet.fetch(:extended_entities, {})
                 .fetch(:media, [])
                 .map { |m| m[:media_url_https] }
         end

         def nowplaying?(tweet)
            main_tweet = tweet.fetch(:retweeted_status, tweet)
            text = main_tweet[:full_text] || main_tweet[:text]
            /nowplaying/i.match?(text)
         end

         def image_url?(url)
            host = URI.parse(url).host
            IMAGE_HOST.any? { |e| host == e }
         end

         def music_url?(url)
            host = URI.parse(url).host
            convertible_music_url?(url) ||
               GENERAL_MUSIC_HOST.any? { |e| host == e } ||
               GENERAL_MUSIC_HOST_RE.any? { |e| host =~ e }
         end

         def convertible_music_url?(url)
            host = URI.parse(url).host
            CONVERTIBLE_MUSIC_HOST.any? { |e| host == e } ||
               CONVERTIBLE_MUSIC_HOST_RE.any? { |e| host =~ e }
         end

         def video_url?(url)
            host = URI.parse(url).host
            VIDEO_HOST.any? { |e| host == e }
         end
      end
   end

   # process media URL and post to other services
   # NOTE: currently only supports posting to Slack
   class MediaTask
      TYPES = %i[all music image video].freeze

      def initialize(arg, logger:, slack_webhook_url:, odesli_api_key: nil)
         # default handling type is music
         @handling_types = (arg || 'music').split(',').map(&:to_sym)
         @handling_types.each { |t| raise "invalid type: #{t}" unless TYPES.include?(t) }

         @slack_webhook_url = slack_webhook_url
         @odesli_api_key = odesli_api_key
         @logger = logger
      end

      def run(_arg, tweets)
         tweets.reverse.each do |tweet|
            urls = extract_media_urls(tweet).filter { |url| to_handle?(url) }
            next if urls.empty?

            urls = organize_urls(urls, drop_image: !tweet[:user][:protected])
            # prepend tweet URL
            urls.prepend(Util.get_tweet_url(tweet[:user][:screen_name], tweet[:id]))

            post_media_to_slack(tweet, urls)
         end
      end

      def extract_media_urls(tweet)
         urls = tweet[:entities][:urls].map { |url| url[:expanded_url] }

         image_urls = MediaUtil.get_image_urls(tweet)
         urls.concat(image_urls)

         mp4_url = MediaUtil.get_mp4_url(tweet)
         urls << mp4_url if mp4_url

         # XXX: use dummy URL for Nowplaying
         urls << 'https://nowplaying.jp' if MediaUtil.nowplaying?(tweet)

         @logger.debug(self.class.name) { "extract_media_urls (#{tweet[:id]}): #{urls}" }

         urls
      end

      def to_handle?(url)
         @handling_types.include?(:all) ||
            MediaUtil.image_url?(url) && @handling_types.include?(:image) ||
            MediaUtil.music_url?(url) && @handling_types.include?(:music) ||
            MediaUtil.video_url?(url) && @handling_types.include?(:video)
      end

      def organize_urls(urls, drop_image: true)
         urls.map do |url|
            if MediaUtil.convertible_music_url?(url) && (converted = convert_music_url(url))
               "#{url} => #{converted}"
            elsif MediaUtil.image_url?(url) && drop_image
               # delete URL since tweet will expand images
               nil
            else
               url
            end
         end.compact
      end

      def post_media_to_slack(tweet, urls)
         @logger.info(self.class.name) { "post media to slack: #{tweet[:id]}, #{urls}" }
         text = %W[`#{tweet[:id]}`].concat(urls.map.with_index { |url, i| "#{i + 1}. #{url}" }).join("\n")
         Util.post_api(@slack_webhook_url,
                       {
                          text: text,
                          unfurl_links: true,
                          mrkdwn: true,
                          attachments: tweet[:user][:protected] ? [gen_slack_attachment(tweet)] : [],
                       })
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      def gen_slack_attachment(tweet)
         main_tweet = tweet.fetch(:retweeted_status, tweet)

         gen_name = proc { |user| "#{user[:name]} (@#{user[:screen_name]}) #{user[:protected] ? '🔒' : ''}" }

         attachment = {
            author_name: gen_name.call(main_tweet[:user]),
            author_link: Util.get_tweet_url(main_tweet[:user][:screen_name], main_tweet[:id]),
            author_icon: main_tweet[:user][:profile_image_url_https],
            text: main_tweet[:full_text] || main_tweet[:text],
            ts: Time.parse(main_tweet[:created_at]).to_i,
            mrkdwn_in: [],
         }

         if tweet[:retweeted_status]
            attachment[:footer] = "Retweeted by #{gen_name.call(tweet[:user])}"
            attachment[:footer_icon] = tweet[:user][:profile_image_url_https]
         end

         if main_tweet[:entities][:media]
            url = main_tweet[:entities][:media].first[:media_url_https]
            # Use resized image because the thumbnail won't show up if an image is too large
            url += '?name=thumb' if URI.parse(url).host == 'pbs.twimg.com'
            attachment[:thumb_url] = url
         end

         @logger.debug(self.class.name) { "gen_slack_attachment: #{attachment}" }
         attachment
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      def convert_music_url(url)
         odesli_info = MediaUtil.get_odesli_info(url, key: @odesli_api_key)
         @logger.debug(self.class.name) { "convert_music_url: #{odesli_info}" }

         links = odesli_info.fetch(:linksByPlatform, {})
         converted ||= links.fetch(:appleMusic, {})[:url]
         converted ||= links.fetch(:itunes, {})[:url]

         converted
      end
   end
end
