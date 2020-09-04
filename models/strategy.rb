class Strategy
  include Mongoid::Document
  include Mongoid::Timestamps
  class RoundingError < StandardError; end

  field :ticker, type: String
  field :name, type: String
  field :score, type: Float
  field :score_fee_weighted, type: Float
  field :manager, type: String
  field :managementType, type: String
  %w[management performance entry exit].each do |r|
    field :"#{r}Fee", type: Float
  end
  field :numberOfAssets, type: Integer
  field :lastRebalanced, type: Time
  field :monthlyRebalancedCount, type: Integer
  %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
    field :"#{r.downcase}", type: Float
  end

  validates_presence_of :ticker

  def calculate_score
    (4 * (month || 0) + 3 * (three_month || 0) + 2 * (six_month || 0) + 1 * (year || 0))
  end

  def calculate_score_fee_weighted
    score * (1 - (managementFee || 0)) * (1 - (performanceFee || 0)) * (1 - (entryFee || 0)) * (1 - (exitFee || 0))
  end

  before_validation do
    self.score = calculate_score
    self.score_fee_weighted = calculate_score_fee_weighted
  end

  def self.admin_fields
    {
      ticker: :text,
      name: :text,
      score: :number,
      score_fee_weighted: :number,
      manager: :text,
      managementType: :text,
      managementFee: :number,
      performanceFee: :number,
      entryFee: :number,
      exitFee: :number,
      numberOfAssets: :number,
      lastRebalanced: :datetime,
      monthlyRebalancedCount: :number,
      day: :number,
      week: :number,
      month: :number,
      three_month: :number,
      six_month: :number,
      year: :number,
      holdings: :collection
    }
  end

  has_many :holdings, dependent: :destroy

  def self.import
    JSON.parse(Iconomi.get('/v1/strategies')).each do |s|
      strategy = Strategy.find_or_create_by(ticker: s['ticker'])
      %w[ticker name manager managementType].each do |r|
        strategy.send("#{r}=", s[r])
      end
      strategy.save
    end
  end

  def self.update
    Strategy.all.each do |strategy|
      strategy.update
    end
  end

  def update
    begin
      j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}"))
      puts self['ticker']
    rescue StandardError
      destroy
      puts "not found: #{self['ticker']}"
      return
    end
    %w[management performance entry exit].each do |r|
      send("#{r}Fee=", j["#{r}Fee"])
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/structure"))
    %w[numberOfAssets lastRebalanced monthlyRebalancedCount].each do |r|
      send("#{r}=", (r == 'lastRebalanced' ? Time.at(j[r]) : j[r]))
    end
    holdings.destroy_all
    j['values'].each do |v|
      asset = Asset.find_or_create_by(ticker: (v['assetTicker'] unless v['assetTicker'].blank?))
      if asset.persisted?
        asset.update_attribute(:name, v['assetName'])
        holdings.create(asset: asset, weight: v['rebalancedWeight'])
      end
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/statistics"))
    %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
      send("#{r.downcase}=", j['returns'][r])
    end
    save
  end

  def self.mature_period
    'SIX_MONTH'
  end

  def self.active_mature(fee_weighted: false)
    where(:monthlyRebalancedCount.gte => 1, :"#{mature_period.downcase}".ne => nil).order(fee_weighted ? 'score_fee_weighted desc' : 'score desc')
  end

  def self.proposed(n: 10)
    assets = {}
    Strategy.active_mature.where(:ticker.ne => 'RISKYBISCUITS').each do |strategy|
      strategy.holdings.each do |holding|
        ticker = holding.asset.ticker
        assets[ticker] = 0 unless assets[ticker]
        assets[ticker] += holding.weight * strategy.score * (holding.asset.multiplier || 1)
      end
    end

    usd = 0
    usd += assets['TUSD'] if assets['TUSD']
    usd += assets['USDC'] if assets['USDC']
    usd += assets['USDT'] if assets['USDT']
    assets = assets.reject { |k, _v| %w[BTC ETH TUSD USDC USDT].include?(k) }

    assets = assets.sort_by { |_k, v| -v }[0..(n - 1)]
    assets << ['USDT', usd]
    total = assets.map { |_k, v| v }.sum
    assets = assets.map { |k, v| [k, v / total] }

    assets = assets.map { |k, v| [k, (v * 0.9).floor(4)] }
    t = assets.map { |_k, v| v }.sum
    assets += [['ETH', (1 - t).round(4)]]

    t = assets.map { |_k, v| v }.sum
    raise Strategy::RoundingError unless t == 1

    assets
  end

  def self.bail(text: nil)
    Mail.deliver do
      from 'notifications@stephenreid.net'
      to 'stephen@stephenreid.net'
      subject 'Strategy#bail'
      body text
    end
    rebalance(bail: true)
    Delayed::Job.where(handler: /method_name: :rebalance/).destroy_all
    delay(run_at: 3.hours.from_now).rebalance(force: true)
  end

  def self.rebalance(n: 10, bail: false, force: false)
    unless force
      usd_weight = JSON.parse(Iconomi.get('/v1/strategies/DECENTCOOP/structure'))['values'].find { |asset| asset['assetTicker'] == 'USDT' }['rebalancedWeight']
      if usd_weight == 0.9
        puts 'Strategy is in bailed state, exiting'
        return
      end
    end

    Mail.deliver do
      from 'notifications@stephenreid.net'
      to 'stephen@stephenreid.net'
      subject "Rebalancing at $#{JSON.parse(Iconomi.get('/v1/user/balance'))['daaList'].find { |daa| daa['ticker'] == 'DECENTCOOP' }['value'].to_i.to_s.reverse.scan(/\d{3}|.+/).join(',').reverse}"
    end

    if bail
      puts 'bailing!'
      weights = [['USDT', 0.9], ['ETH', 0.1]]
      data = {
        ticker: 'DECENTCOOP',
        values: weights.map do |ticker, p|
          { assetTicker: ticker, rebalancedWeight: p }
        end,
        speedType: 'FAST'
      }
      Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
    else
      puts 'setting strategy'
      success = nil
      until success

        begin
          weights = Strategy.proposed(n: n)
        rescue StandardError => e
          Airbrake.notify(e)
          raise e
        end

        data = {
          ticker: 'DECENTCOOP',
          values: weights.map do |ticker, p|
            { assetTicker: ticker, rebalancedWeight: p }
          end,
          speedType: 'MEDIUM'
        }

        puts n
        puts data.to_json
        begin
          Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
          success = true
        rescue StandardError
          n -= 1
        end
      end
    end
  end
end
