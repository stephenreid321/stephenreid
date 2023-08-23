class Tweet
  include Mongoid::Document
  include Mongoid::Timestamps
  extend Dragonfly::Model

  field :tweet_id, type: Integer
  field :data, type: Hash
  field :html, type: String
  field :timeline, type: String
  field :image_uid, type: String
  field :hidden, type: Boolean

  def self.admin_fields
    {
      tweet_id: { type: :number, disabled: true },
      data: { type: :text_area, disabled: true },
      html: { type: :text_area, disabled: true },
      image_uid: { type: :text, disabled: true },
      image: :image,
      timeline: :text,
      hidden: :check_box
    }
  end

  validates_uniqueness_of :tweet_id

  dragonfly_accessor :image
  before_validation do
    if image
      begin
        if %w[jpeg png gif pam].include?(image.format)
          image.name = "#{SecureRandom.uuid}.#{image.format}"
        else
          errors.add(:image, 'must be an image')
        end
      rescue StandardError
        self.image = nil
        errors.add(:image, 'must be an image')
      end
    end
  end

  def self.import
    Tweet.and(:hidden.ne => true).delete_all
    Tweet.and(:'data.age'.gt => 14.days).delete_all
    Tweet.nitter
  end

  def self.nitter
    twitter_friends = TwitterFriend.all
    c = twitter_friends.count
    twitter_friends.each_with_index do |tf, i|
      username = tf['Username']
      username = username[1..-1] if username[0] == '@'
      timeline = tf['Timeline']
      puts "#{i + 1}/#{c} #{username}"
      if Tweet.find_by(:'data.user.username' => username, :timeline => timeline, :hidden.ne => true)
        puts 'already imported, skipping'
        next
      end
      begin
        Tweet.nitter_user(username, timeline)
      rescue StandardError => e
        puts e
      end
    end
  end

  def self.nitter_user(username, timeline, cursor: nil)
    a = Mechanize.new
    oldest_tweet_in_cursor_created_at = nil
    url = "https://#{ENV['NITTER_DOMAIN']}/#{username}?cursor=#{cursor}"
    puts url
    page = begin; a.get(url); rescue Mechanize::ResponseCodeError; return; end
    page.search('.timeline .timeline-item .tweet-body').each do |item|
      t = {}
      t['user'] = {}
      t['user']['username'] = username
      t['created_at'] = Time.parse(item.search('.tweet-date a[title]')[0]['title']).iso8601
      t['id'] = item.parent.search('.tweet-link')[0]['href'].split('/').last.split('#').first
      t['age'] = Time.now - Time.iso8601(t['created_at'])

      t['public_metrics'] = {}
      t['public_metrics']['like_count'] = item.search('.icon-heart')[0].parent.text
      t['public_metrics']['retweet_count'] = item.search('.icon-retweet')[0].parent.text
      t['public_metrics']['quote_count'] = item.search('.icon-quote')[0].parent.text
      t['user']['public_metrics'] = {}
      t['user']['public_metrics']['followers_count'] = page.search('.followers .profile-stat-num').text.gsub(',', '').to_i

      t['likes_per_follower'] = t['public_metrics']['like_count'].to_f / t['user']['public_metrics']['followers_count']
      t['likes_per_second'] = t['public_metrics']['like_count'].to_f / t['age']
      t['likes_per_follower_per_second'] = t['public_metrics']['like_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
      t['retweets_per_follower'] = t['public_metrics']['retweet_count'].to_f / t['user']['public_metrics']['followers_count']
      t['retweets_per_second'] = t['public_metrics']['retweet_count'].to_f / t['age']
      t['retweets_per_follower_per_second'] = t['public_metrics']['retweet_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])
      t['quotes_per_follower'] = t['public_metrics']['quote_count'].to_f / t['user']['public_metrics']['followers_count']
      t['quotes_per_second'] = t['public_metrics']['quote_count'].to_f / t['age']
      t['quotes_per_follower_per_second'] = t['public_metrics']['quote_count'].to_f / (t['user']['public_metrics']['followers_count'] * t['age'])

      oldest_tweet_in_cursor_created_at = Time.iso8601(t['created_at'])
      Tweet.create(tweet_id: t['id'], data: t, timeline: timeline) if item.search('.retweet-header').empty?
    end
    return if !oldest_tweet_in_cursor_created_at || oldest_tweet_in_cursor_created_at < 14.days.ago

    cursor = page.search('.show-more a').last['href'].split('cursor=').last
    puts cursor
    Tweet.nitter_user(username, timeline, cursor: cursor)
  end

  def self.api
    Faraday.new 'https://api.twitter.com/2' do |f|
      f.request :oauth, consumer_key: ENV['TWITTER_KEY'], consumer_secret: ENV['TWITTER_SECRET'], token: ENV['TWITTER_ACCESS_TOKEN'], token_secret: ENV['TWITTER_ACCESS_TOKEN_SECRET']
      f.request :json
      f.response :json
      f.adapter :net_http
    end
  end

  def self.timeline(url)
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
  rescue StandardError
    nil
  end

  def get_image
    # added chrome buildpack
    f = Ferrum::Browser.new
    f.go_to("https://platform.twitter.com/embed/Tweet.html?id=#{tweet_id}")
    sleep 1
    width = 1
    while width == 1
      image = Magick::Image.from_blob(Base64.decode64(f.screenshot(encoding: :base64))).first
      image.trim!
      width = image.columns
    end
    f.quit
    self.image = image.to_blob
  end

  def set_image!
    return if image

    get_image
    save
  end
  handle_asynchronously :set_image!

  def self.timelines
    {
      'Home' => ["users/#{ENV['TWITTER_USER_ID']}/timelines/reverse_chronological", nil],
      'AI' => ['lists/1671431015573733381/tweets', nil],
      'Crypto Twitter' => ['lists/1585548222935736321/tweets', nil],
      'Greenpill' => ['lists/1610587490670317573/tweets', 24.hours.ago],
      'Contemplatives' => ['lists/1610571716199055360/tweets', 24.hours.ago]
    }
  end

  def self.import_timelines
    # r = Tweet.api.get("users/#{ENV['TWITTER_USER_ID']}/owned_lists")
    # }.merge(r.body['data'].map { |x| [x['name'], "lists/#{x['id']}/tweets"] }.to_h)
    timelines.each do |timeline, (url, refresh_time)|
      first_tweet = Tweet.where(timeline: timeline).order('created_at desc').first
      next if refresh_time && first_tweet && first_tweet.created_at > refresh_time

      Tweet.delete_all(timeline: timeline)
      tweets = Tweet.timeline(url)
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
