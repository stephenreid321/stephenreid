class Tweet
  include Mongoid::Document
  include Mongoid::Timestamps

  field :data, type: Hash
  field :html, type: String
  field :timeline, type: String

  def self.admin_fields
    {
      data: { type: :text_area, disabled: true },
      timeline: :text
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

  def self.timeline(url, start_time: nil)
    tweets = []
    users = []
    media = []
    referenced_tweets = []
    q = 'tweet.fields=referenced_tweets,entities,public_metrics,created_at,attachments&user.fields=profile_image_url,public_metrics&expansions=author_id,attachments.media_keys,referenced_tweets.id,referenced_tweets.id.author_id&media.fields=media_key,preview_image_url,type,url,variants'
    r = Tweet.api.get("#{url}?#{q}")
    tweets += r.body['data']
    users += r.body['includes']['users'] if r.body['includes'] && r.body['includes']['users']
    media += r.body['includes']['media'] if r.body['includes'] && r.body['includes']['media']
    referenced_tweets += r.body['includes']['tweets'] if r.body['includes'] && r.body['includes']['tweets']
    pagination_token = r.body['meta']['next_token']
    while pagination_token
      r = Tweet.api.get("#{url}?#{q}&pagination_token=#{pagination_token}")
      tweets += r.body['data']
      users += r.body['includes']['users'] if r.body['includes'] && r.body['includes']['users']
      media += r.body['includes']['media'] if r.body['includes'] && r.body['includes']['media']
      referenced_tweets += r.body['includes']['tweets'] if r.body['includes'] && r.body['includes']['tweets']
      pagination_token = r.body['meta']['next_token']
      puts pagination_token
      break if start_time && Time.iso8601(tweets.last['created_at']) < start_time
    end
    tweets.each do |t|
      t['user'] = users.find { |u| u['id'] == t['author_id'] }
      if t['attachments'] && t['attachments']['media_keys']
        t['attachments']['media_keys'].each do |media_key|
          t['media'] ||= []
          t['media'] << media.find { |m| m['media_key'] == media_key }
        end
      end
      if t['referenced_tweets']
        t['referenced_tweets'].each_with_index do |referenced_tweet, i|
          next unless (t['referenced_tweets'][i]['tweet'] = referenced_tweets.find { |t| t['id'] == referenced_tweet['id'] })

          t['referenced_tweets'][i]['tweet']['user'] = users.find do |u|
            u['id'] == referenced_tweet['tweet']['author_id']
          end

          next unless t['referenced_tweets'][i]['tweet']['attachments'] && t['referenced_tweets'][i]['tweet']['attachments']['media_keys']

          t['referenced_tweets'][i]['tweet']['attachments']['media_keys'].each do |media_key|
            t['referenced_tweets'][i]['tweet']['media'] ||= []
            t['referenced_tweets'][i]['tweet']['media'] << media.find { |m| m['media_key'] == media_key }
          end
        end
      end
      t['age'] = Time.now - Time.iso8601(t['created_at'])
      t['likes_per_follower'] = t['public_metrics']['like_count'].to_f / t['user']['public_metrics']['followers_count']
      t['likes_per_second'] = t['public_metrics']['like_count'].to_f / t['age']
      t['likes_per_follower_per_second'] = t['public_metrics']['like_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
      t['retweets_per_follower'] = t['public_metrics']['retweet_count'].to_f / t['user']['public_metrics']['followers_count']
      t['retweets_per_second'] = t['public_metrics']['retweet_count'].to_f / t['age']
      t['retweets_per_follower_per_second'] = t['public_metrics']['retweet_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
      t['quotes_per_follower'] = t['public_metrics']['quote_count'].to_f / t['user']['public_metrics']['followers_count']
      t['quotes_per_second'] = t['public_metrics']['quote_count'].to_f / t['age']
      t['quotes_per_follower_per_second'] = t['public_metrics']['quote_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
    end
  end

  def url
    Tweet.url(data)
  end

  def self.url(data)
    "https://twitter.com/#{data['user']['username']}/status/#{data['id']}"
  end

  def get_html
    JSON.parse(Faraday.get("https://publish.twitter.com/oembed?omit_script=1&url=#{"https://twitter.com/#{data['user']['username']}/status/#{data['id']}"}").body)['html']
  end

  def self.import
    Tweet.delete_all
    r = Tweet.api.get("users/#{ENV['TWITTER_USER_ID']}/owned_lists")
    timelines = {
      'Home' => ["users/#{ENV['TWITTER_USER_ID']}/timelines/reverse_chronological", nil],
      'Crypto Twitter' => ['lists/1585548222935736321/tweets', 3.days.ago],
      'Greenpill' => ['lists/1610587490670317573/tweets', 3.days.ago],
      'Contemplatives' => ['lists/1610571716199055360/tweets', 3.days.ago]
    }
    # }.merge(r.body['data'].map { |x| [x['name'], "lists/#{x['id']}/tweets"] }.to_h)
    timelines.each do |timeline, (url, start_time)|
      tweets = Tweet.timeline(url, start_time: start_time)
      tweets.each do |t|
        Tweet.create(data: t, timeline: timeline)
      end
    end
  end

  # get all members of a list
  def self.list_members(list_id)
    r = Tweet.api.get("lists/#{list_id}/members")
    users = r.body['data']
    pagination_token = r.body['meta']['next_token']
    while pagination_token
      r = Tweet.api.get("lists/#{list_id}/followers?pagination_token=#{pagination_token}")
      users += r.body['data']
      pagination_token = r.body['meta']['next_token']
    end
    users
  end

  # get all followers of a user
  def self.following(user_id)
    r = Tweet.api.get("users/#{user_id}/following")
    users = r.body['data']
    pagination_token = r.body['meta']['next_token']
    while pagination_token
      r = Tweet.api.get("users/#{user_id}/following?pagination_token=#{pagination_token}")
      users += r.body['data']
      pagination_token = r.body['meta']['next_token']
    end
    users
  end
end
