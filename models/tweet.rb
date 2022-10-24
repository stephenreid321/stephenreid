class Tweet
  include Mongoid::Document
  include Mongoid::Timestamps

  field :data, type: Hash
  field :html, type: String

  def self.admin_fields
    {
      data: { type: :text_area, disabled: true }
    }
  end

  def self.api
    Faraday.new 'https://api.twitter.com/2' do |f|
      f.request :oauth, consumer_key: ENV['TWITTER_KEY'], consumer_secret: ENV['TWITTER_SECRET'], token: ENV['TWITTER_ACCESS_TOKEN'], token_secret: ENV['TWITTER_ACCESS_TOKEN_SECRET']
      f.request :json
      f.response :json
      f.adapter :net_http
    end
  end

  def self.timeline
    tweets = []
    users = []
    q = 'tweet.fields=public_metrics,created_at&expansions=author_id&user.fields=public_metrics'
    r = Tweet.api.get("users/514812230/timelines/reverse_chronological?#{q}")
    tweets += r.body['data']
    users += r.body['includes']['users']
    pagination_token = r.body['meta']['next_token']
    while pagination_token
      r = Tweet.api.get("users/514812230/timelines/reverse_chronological?#{q}&pagination_token=#{pagination_token}")
      tweets += r.body['data']
      users += r.body['includes']['users']
      pagination_token = r.body['meta']['next_token']
      puts pagination_token
    end
    tweets.each do |t|
      t['user'] = users.find { |u| u['id'] == t['author_id'] }
      t['age'] = Time.now - Time.iso8601(t['created_at'])
      t['likes_per_follower'] = t['public_metrics']['like_count'].to_f / t['user']['public_metrics']['followers_count']
      t['likes_per_second'] = t['public_metrics']['like_count'].to_f / t['age']
      t['likes_per_follower_per_second'] = t['public_metrics']['like_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
      t['retweets_per_follower'] = t['public_metrics']['retweet_count'].to_f / t['user']['public_metrics']['followers_count']
      t['retweets_per_second'] = t['public_metrics']['retweet_count'].to_f / t['age']
      t['retweets_per_follower_per_second'] = t['public_metrics']['retweet_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
    end
  end

  def get_html
    JSON.parse(Faraday.get("https://publish.twitter.com/oembed?omit_script=1&url=#{"https://twitter.com/#{data['user']['username']}/status/#{data['id']}"}").body)['html']
  end

  def self.import
    Tweet.delete_all
    tweets = Tweet.timeline
    tweets.each do |t|
      Tweet.create(data: t)
    end
  end
end
