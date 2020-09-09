class Coin
  include Mongoid::Document
  include Mongoid::Timestamps

  field :slug, type: String
  field :symbol, type: String
  field :name, type: String
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
  field :bought, type: Boolean

  def self.admin_fields
    {
      slug: :text,
      symbol: :text,
      name: :text,
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
      bought: :check_box
    }
  end

  def self.import
    hidden = Coin.where(hidden: true).pluck(:slug)
    Coin.delete_all
    agent = Mechanize.new
    i = 1
    until (coins = JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&per_page=250&price_change_percentage=1h,24h,7d&page=#{i}").body)).empty?
      i += 1
      coins.each do |c|
        puts c['name']
        coin = Coin.create!(slug: c['id'])
        %w[symbol name current_price market_cap market_cap_rank total_volume price_change_percentage_1h_in_currency price_change_percentage_24h_in_currency price_change_percentage_7d_in_currency].each do |r|
          coin.send("#{r}=", c[r])
        end
        coin.save
      end
    end
    Coin.where(:slug.in => hidden).set(hidden: true)
  end

  def self.update
    Coin.all.each do |coin|
      coin.update
    end
  end

  def update
    agent = Mechanize.new
    c = JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/#{slug}").body)
    self.website = c['links']['homepage'].first
    self.twitter_username = c['links']['twitter_screen_name']
    self.twitter_followers = c['community_data']['twitter_followers']
    save
  end
end
