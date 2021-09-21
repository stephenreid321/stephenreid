class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  field :ticker, type: String
  field :name, type: String
  field :multiplier, type: Float
  field :verified, type: Boolean
  field :excluded, type: Boolean

  validates_presence_of :ticker

  has_many :holdings, dependent: :destroy

  def self.admin_fields
    {
      ticker: :text,
      name: :text,
      multiplier: :number,
      verified: :check_box,
      excluded: :check_box,
      holdings: :collection
    }
  end

  def self.unverified
    where(:verified.ne => true)
  end

  def self.coingecko(coingecko_id)
    agent = Mechanize.new
    JSON.parse(agent.get("https://api.coingecko.com/api/v3/coins/#{coingecko_id.downcase}").body)
  end
end
