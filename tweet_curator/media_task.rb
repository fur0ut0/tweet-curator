# frozen_string_literal: true

module TweetCurator
   # process media URL and post to other services
   class MediaTask
      def initialize(*filter_mode, odesli_token: nil)
         @filter_types = to_filter_types(filter_mode)
         @odesli_token = odesli_token
      end

      def run(tweets, post_mode: 'slack')
         # TODO
      end

      private

      def to_filter_types(filter_mode)
         # TODO
         filter_mode
      end
   end
end
