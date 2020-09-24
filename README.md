# tweet-curator

* fetch twitter home timeline and execute pipelines for it

## usage

To transfer tweets including media links to Slack channel, you need setup some environment variables.

* `TWITTER_CONSUMER_KEY`, `TWITTER_CONSUMER_SECRET`, `TWITTER_ACCESS_TOKEN`, `TWITTER_ACCESS_TOKEN_SECRET`: Twitter API token
* `SLACK_WEBHOOK_URL`: Slack Webhook URL (e.g. https://hooks.slack.com/services/hoge/fuga/piyo)
* `REDIS_URL`: Redis URL (e.g. redis://user:password@hostname:6379)

You can set these variables in `.env` file.

Then, the following command would do the job:

```shell
$ bundle install
$ bundle exec ruby app.rb mediainfo
```

