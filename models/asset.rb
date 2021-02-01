class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ticker, type: String
  field :name, type: String
  field :multiplier, type: Float
  field :verified, type: Boolean

  validates_presence_of :ticker

  has_many :holdings, dependent: :destroy

  def self.admin_fields
    {
      ticker: :text,
      name: :text,
      multiplier: :number,
      holdings: :collection
    }
  end

  def self.loopring_tickers
    agent = Mechanize.new
    JSON.parse(agent.get('https://api.coingecko.com/api/v3/exchanges/loopring').body)['tickers']
  end

  def self.loopring_symbols
    loopring_tickers.map { |ticker| [ticker['base'], ticker['target']] }.flatten.uniq
  end

  def self.loopring_coingecko_id(symbol)
    loopring_tickers.find do |ticker|
      return ticker['coin_id'] if ticker['base'] == symbol
      return ticker['target_coin_id'] if ticker['target'] == symbol
    end
  end

  def self.coingecko(coingecko_id)
    agent = Mechanize.new
    JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/#{coingecko_id.downcase}").body)
  end
end
