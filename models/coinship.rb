class Coinship
  include Mongoid::Document
  include Mongoid::Timestamps

  field :market_cap_rank_prediction, type: Integer
  field :market_cap_rank_prediction_conviction, type: Float
  field :hidden, type: Boolean
  field :starred, type: Boolean
  field :units, type: Float
  field :staked_units, type: Float
  field :notes, type: String

  belongs_to :account
  belongs_to :coin
  belongs_to :tag, optional: true

  validates_uniqueness_of :coin, scope: :account

  def self.admin_fields
    {
      account_id: :lookup,
      coin_id: :lookup,
      tag_id: :lookup,
      units: :number,
      staked_units: :number,
      notes: :text_area,
      market_cap_rank_prediction: :number,
      market_cap_rank_prediction_conviction: :number,
      hidden: :check_box,
      starred: :check_box
    }
  end

  def market_cap_at_predicted_rank
    if (p = market_cap_rank_prediction)
      mc = nil
      until mc
        mc = Coin.find_by(market_cap_rank: p).try(:market_cap)
        p += 1
        break if p > market_cap_rank_prediction + 5
      end
      mc
    end
  end

  def market_cap_change_prediction
    (market_cap_at_predicted_rank / coin.market_cap) * (market_cap_rank_prediction_conviction || 1) if market_cap_at_predicted_rank && coin.market_cap && (coin.market_cap > 0)
  end

  def all_units
    (units || 0) + (staked_units || 0)
  end

  def holding
    (all_units || 0) * (coin.current_price || 0)
  end

  def remote_update
    coin.remote_update
    if starred
      u = 0
      if platform == 'ethereum'
        ENV['ETH_ADDRESSES'].split(',').each do |a|
          u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=tokenbalance&contractaddress=#{contract_address}&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / 10**(decimals || 18).to_f
        end
      elsif platform == 'binance-smart-chain'
        ENV['ETH_ADDRESSES'].split(',').each do |a|
          u += JSON.parse(agent.get("https://api.bscscan.com/api?module=account&action=tokenbalance&contractaddress=#{contract_address}&address=#{a}&tag=latest&apikey=#{ENV['BSCSCAN_API_KEY']}").body)['result'].to_i / 10**(decimals || 18).to_f
        end
      elsif symbol == 'ETH'
        ENV['ETH_ADDRESSES'].split(',').each do |a|
          u += JSON.parse(agent.get("https://api.etherscan.io/api?module=account&action=balance&address=#{a}&tag=latest&apikey=#{ENV['ETHERSCAN_API_KEY']}").body)['result'].to_i / 10**(decimals || 18).to_f
        end
      elsif symbol == 'BNB'
        ENV['ETH_ADDRESSES'].split(',').each do |a|
          u += JSON.parse(agent.get("https://api.bscscan.io/api?module=account&action=balance&address=#{a}&tag=latest&apikey=#{ENV['BSCSCAN_API_KEY']}").body)['result'].to_i / 10**(decimals || 18).to_f
        end
      else

        client = Binance::Client::REST.new api_key: ENV['BINANCE_API_KEY'], secret_key: ENV['BINANCE_API_SECRET']
        balances = client.account_info['balances']
        bc = balances.find do |b|
          b['asset'] == symbol
        end
        u += (bc['free'].to_f + bc['locked'].to_f) if bc

      end

      self.units = u
    else
      self.units = nil
    end
    save!
  end
end
