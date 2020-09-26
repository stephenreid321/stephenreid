class Coin
  include Mongoid::Document
  include Mongoid::Timestamps

  field :slug, type: String
  field :symbol, type: String
  field :name, type: String
  field :platform, type: String
  field :current_price, type: Float
  field :market_cap, type: Integer
  field :market_cap_rank, type: Integer
  field :total_volume, type: Integer
  field :price_change_percentage_1h_in_currency, type: Float
  field :price_change_percentage_24h_in_currency, type: Float
  field :price_change_percentage_7d_in_currency, type: Float
  field :website, type: String
  field :twitter_username, type: String
  field :twitter_followers, type: Integer
  field :hidden, type: Boolean
  field :starred, type: Boolean

  before_validation do
    self.symbol = symbol.try(:upcase)
  end

  def self.admin_fields
    {
      slug: :text,
      symbol: :text,
      name: :text,
      platform: :text,
      current_price: :number,
      market_cap: :number,
      market_cap_rank: :number,
      total_volume: :number,
      price_change_percentage_1h_in_currency: :number,
      price_change_percentage_24h_in_currency: :number,
      price_change_percentage_7d_in_currency: :number,
      website: :url,
      twitter_username: :text,
      twitter_followers: :number,
      hidden: :check_box,
      starred: :check_box
    }
  end

  def eth?
    platform == 'ethereum'
  end

  def score_index(x, coins)
    index = coins.order("#{x} desc").pluck(:symbol).index(symbol) + 1
    min = coins.pluck(x).compact.min
    max = coins.pluck(x).compact.max
    score = 100 * ((send(x) - min) / (max - min))
    [score, index]
  end

  def self.import
    hidden_slugs = Coin.where(hidden: true).pluck(:slug)
    starred_slugs = Coin.where(starred: true).pluck(:slug)
    Coin.delete_all
    agent = Mechanize.new
    i = 1
    until (coins = JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&per_page=250&price_change_percentage=1h,24h,7d&page=#{i}").body)).empty?
      i += 1
      coins.each do |c|
        puts c['name']
        if alt = Coin.find_by(symbol: c['symbol'])
          if !alt.market_cap_rank || c['market_cap_rank'] < alt.market_cap_rank
            alt.destroy
          else
            next
          end
        end
        coin = Coin.create!(slug: c['id'])
        %w[symbol name current_price market_cap market_cap_rank total_volume price_change_percentage_1h_in_currency price_change_percentage_24h_in_currency price_change_percentage_7d_in_currency].each do |r|
          coin.send("#{r}=", c[r])
        end
        coin.hidden = hidden_slugs.include?(coin.slug)
        coin.starred = starred_slugs.include?(coin.slug)
        coin.save
      end
    end
  end

  def self.update
    Coin.all.each do |coin|
      coin.update
    end
  end

  def update
    agent = Mechanize.new
    c = JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/#{slug}").body)
    self.platform = c['asset_platform_id']
    self.website = c['links']['homepage'].first
    self.twitter_username = c['links']['twitter_screen_name']
    self.twitter_followers = c['community_data']['twitter_followers']
    save
  end
end
