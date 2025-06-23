class Coinship
  include Mongoid::Document
  include Mongoid::Timestamps

  field :market_cap_rank_prediction, type: Integer
  field :market_cap_rank_prediction_conviction, type: Float
  field :starred, type: Boolean
  field :units, type: Float
  field :units_elsewhere, type: String

  belongs_to :account, index: true
  belongs_to :coin, index: true
  belongs_to :tag, optional: true, index: true

  validates_uniqueness_of :coin, scope: :account

  def self.admin_fields
    {
      account_id: :lookup,
      coin_id: :lookup,
      tag_id: :lookup,
      units: :number,
      units_elsewhere: :text,
      market_cap_rank_prediction: :number,
      market_cap_rank_prediction_conviction: :number,
      starred: :check_box
    }
  end

  def market_cap_at_predicted_rank
    return unless (p = market_cap_rank_prediction)

    mc = nil
    until mc
      mc = Coin.find_by(market_cap_rank: p).try(:market_cap)
      p += 1
      break if p > market_cap_rank_prediction + 3
    end
    mc
  end

  def market_cap_change_prediction
    (market_cap_at_predicted_rank / coin.market_cap) * (market_cap_rank_prediction_conviction || 1) if market_cap_at_predicted_rank && coin.market_cap && (coin.market_cap > 0)
  end

  def self.units_elsewhere_sum(units_elsewhere)
    if units_elsewhere
      units_elsewhere.split.map do |x|
        Float(x.gsub(',', ''))
      rescue StandardError
        nil
      end.compact.sum
    else
      0
    end
  end

  def units_elsewhere_sum
    Coinship.units_elsewhere_sum(units_elsewhere)
  end

  def all_units
    (units || 0) + (units_elsewhere_sum || 0)
  end

  def holding
    (all_units || 0) * (coin.price || 0)
  end

  def remote_update(skip_coin_update: nil)
    coin.remote_update unless skip_coin_update

    agent = Mechanize.new
    if starred
      u = 0

      begin
        if coin.platform == 'ethereum'
          account.eth_address_hashes.each do |a|
            u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=tokenbalance&contractaddress=#{coin.contract_address}&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / (10**(coin.decimals || 18).to_f)
          end
        elsif coin.symbol == 'ETH'
          account.eth_address_hashes.each do |a|
            u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=balance&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / (10**(coin.decimals || 18).to_f)
          end
        end
      rescue StandardError => e
        # Airbrake.notify(e)
        return
      end

      self.units = u
    else
      self.units = nil
    end
    save!
  end
end
