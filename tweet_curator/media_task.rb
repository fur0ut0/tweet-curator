# frozen_string_literal: true

module TweetCurator
   # process media URL and post to other services
   class MediaTask
      FILTER_TYPES = %i[all music image video].freeze

      def initialize(arg, slack_webhook_url:, odesli_api_key: nil)
         # default filter type is music
         @filter_types = (arg || 'music').split(',').map(&:to_sym)
         @filter_types.each { |t| raise "invalid filter type: #{t}" unless FILTER_TYPES.include?(t) }

         @slack_webhook_url = slack_webhook_url
         @odesli_api_key = odesli_api_key
      end

      def run(tweets)
         # TODO
      end
   end
end
