require 'rubygems'
require 'twitter'

require 'psych'
require 'json'

require './utils'

class TwitterHelper

  def initialize(opts)
    Twitter.configure do |config|
      config.consumer_key = opts['consumer_key']
      config.consumer_secret = opts['consumer_secret']
    end

    @default_user_tweets_options = opts.slice %w(count trim_user exclude_replies contributor_details include_rts)
  end

  # returns an enumerator of all tweets for a given user
  def user_tweets(user_hash, opts = {})
    client = self.client(user_hash)
    user_name = user_hash['name']

    opts = @default_user_tweets_options.merge(opts)

    expected_count = opts['count'] || 20
    max_id = nil

    Enumerator.new do |yielder|
      # make API request & return results in an enumerator
      loop do
        query_opts = opts
        if max_id
          query_opts = opts.clone
          query_opts['max_id'] = max_id
        end

        results = client.user_timeline(user_name, query_opts)
        results.each do |tweet|
          id = tweet['id']
          max_id = id if (max_id.nil? || id < max_id) # max_id should descend
          yielder << tweet
        end

        # TODO catch RateLimitExceeded exception

        break if results.size < expected_count # this can happen if optional params are passed in...

        max_id -= 1 # subtract 1 from max_id to avoid redundant messages
      end
    end
  end

  def client(user_hash)
  	Twitter::Client.new(
  		oauth_token: user_hash['token'],
  		oauth_token_secret: user_hash['secret']
  	)
  end
end


# script
if __FILE__ == $PROGRAM_NAME
  @twitter = load_me
end

def load_me
  app_config = Psych.load_file './config/dev.yml'
  accounts = JSON.parse File.read './input/twitter_accounts.json'

  TwitterHelper.new(app_config['twitter']).client(accounts['me'])
end
