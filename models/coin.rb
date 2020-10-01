class Coin
  include Mongoid::Document
  include Mongoid::Timestamps

  field :slug, type: String
  field :tag, type: String
  field :decimals, type: Integer
  field :units, type: Float
  field :contract_address, type: String
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
      tag: :text,
      decimals: :integer,
      units: :number,
      contract_address: :text,
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
    agent = Mechanize.new
    i = 1
    until (coins = JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&per_page=250&price_change_percentage=1h,24h,7d&page=#{i}").body)).empty?
      i += 1
      coins.each do |c|
        puts c['symbol'].upcase
        coin = Coin.find_or_create_by!(slug: c['id'])
        %w[symbol name current_price market_cap market_cap_rank total_volume price_change_percentage_1h_in_currency price_change_percentage_24h_in_currency price_change_percentage_7d_in_currency].each do |r|
          coin.send("#{r}=", c[r])
        end
        coin.save
      end
    end
  end

  def self.symbol(symbol)
    Coin.where(symbol: symbol.upcase).order('total_volume desc').first
  end

  def self.update
    Coin.all.each do |coin|
      coin.update
    end
  end

  def update
    agent = Mechanize.new
    c = JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/#{slug}").body)
    %w[current_price market_cap total_volume price_change_percentage_1h_in_currency price_change_percentage_24h_in_currency price_change_percentage_7d_in_currency].each do |r|
      send("#{r}=", c['market_data'][r]['usd'])
    end
    %w[market_cap_rank].each do |r|
      send("#{r}=", c['market_data'][r])
    end
    self.contract_address = c['contract_address']
    self.platform = c['asset_platform_id']
    self.website = c['links']['homepage'].first
    self.twitter_username = c['links']['twitter_screen_name']
    self.twitter_followers = c['community_data']['twitter_followers']
    if starred
      u = 0
      %w[0x72e1638bd8cd371bfb04cf665b749a0e4ae38324 0x81a06F24B206d420F201eC9844141Bf62804b257].each do |a|
        u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=tokenbalance&contractaddress=#{contract_address}&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / 10**(decimals || 18).to_f
      end

      client = Binance::Client::REST.new api_key: ENV['BINANCE_API_KEY'], secret_key: ENV['BINANCE_API_SECRET']
      balances = client.account_info['balances'].select { |b| b['free'].to_f > 0 }
      bc = balances.find { |b| b['asset'] == symbol }
      u += bc['free'].to_f if bc

      self.units = u
    else
      self.units = nil
    end
    save
  end
end
