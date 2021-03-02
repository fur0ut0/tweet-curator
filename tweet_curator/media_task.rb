# frozen_string_literal: true

module TweetCurator
   # process media URL and post to other services
   class MediaTask
      FILTER_TYPES = %i[all music image video].freeze

      def initialize(filter_types = ['music'], env_fetcher = nil)
         @filter_types = filter_types.map(&:to_sym)
         @odesli_api_key = env_fetcher&.get(:ODESLI_API_KEY)
      end

      def run(tweets, post_mode: 'slack')
         # TODO
      end
   end
end
