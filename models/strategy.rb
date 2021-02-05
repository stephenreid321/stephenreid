class Strategy
  include Mongoid::Document
  include Mongoid::Timestamps
  class RoundingError < StandardError; end
  class RebalancingError < StandardError; end

  MONTH_FACTOR = 4
  THREE_MONTH_FACTOR = 3
  SIX_MONTH_FACTOR = 2
  YEAR_FACTOR = 1

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
    field :"r#{r.downcase}", type: Float
  end
  field :verified, type: Boolean

  validates_presence_of :ticker

  def calculate_score
    ((MONTH_FACTOR * (rmonth || 0)) + (THREE_MONTH_FACTOR * (rthree_month || 0)) + (SIX_MONTH_FACTOR * (rsix_month || 0)) + (YEAR_FACTOR * (ryear || 0)))
  end

  def calculate_score_fee_weighted
    score * (1 - (managementFee || 0)) * (1 - (performanceFee || 0)) * (1 - (entryFee || 0)) * (1 - (exitFee || 0))
  end

  before_validation do
    self.score = calculate_score
    self.score_fee_weighted = calculate_score_fee_weighted
  end

  def score_index(x, strategies: Strategy.active_mature)
    index = strategies.order("#{x} desc").pluck(:ticker).index(ticker) + 1
    min = strategies.pluck(x).compact.min
    max = strategies.pluck(x).compact.max
    score = 100 * ((send(x) - min) / (max - min))
    [score, index]
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
      rday: :number,
      rweek: :number,
      rmonth: :number,
      rthree_month: :number,
      rsix_month: :number,
      ryear: :number,
      verified: :check_box,
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
      send("r#{r.downcase}=", j['returns'][r])
    end
    save
  end

  def max_maturity
    m = nil
    %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
      m = r if send("r#{r.downcase}")
    end
    m
  end

  def self.unverified
    where(:verified.ne => true)
  end

  def self.active_mature(mature_period: 'THREE_MONTH')
    where(:monthlyRebalancedCount.gte => 1, :"r#{mature_period.downcase}".ne => nil, :verified => true)
  end

  def self.proposed(n: 10)
    assets = {}
    Strategy.active_mature.where(:ticker.ne => 'DECENTCOOP').each do |strategy|
      strategy.holdings.each do |holding|
        next unless holding.asset.verified

        ticker = holding.asset.ticker
        assets[ticker] = 0 unless assets[ticker]
        assets[ticker] += holding.weight * strategy.score * (holding.asset.multiplier || 1)
      end
    end

    %w[USDT TUSD].each do |s|
      if assets[s]
        assets['USDC'] += assets[s]
        assets.delete(s)
      end
    end

    # offset to take into account possibility of negative scores
    offset = assets.values.min
    assets = Hash[assets.map { |k, v| [k, v - offset] }]

    # restrict to top n assets
    assets = assets.sort_by { |_k, v| -v }[0..(n - 1)]
    t = assets.map { |_k, v| v }.sum
    assets = Hash[assets.map { |k, v| [k, v / t] }]

    # include at least 10% ETH
    if !assets['ETH'] || assets['ETH'] < 0.1
      assets.delete('ETH')
      t = assets.map { |_k, v| v }.sum
      assets = Hash[assets.map { |k, v| [k, v / t] }]
      assets = Hash[assets.map { |k, v| [k, v * (1 - 0.1)] }]
      assets['ETH'] = 0.1
    end

    # make sure asset weights sum to exactly 1
    assets = Hash[assets.map { |k, v| [k, v.floor(4)] }]
    t = assets.map { |_k, v| v }.sum
    assets['ETH'] += (1 - t)
    assets['ETH'] = assets['ETH'].round(4)

    t = assets.map { |_k, v| v }.sum
    raise Strategy::RoundingError(assets.to_json) unless t == 1

    assets.map { |k, v| [k, v] }
  end

  def self.bail
    Delayed::Job.where(handler: /method_name: :rebalance/).destroy_all
    rebalance(bail: true)
    # delay(run_at: 1.hours.from_now).rebalance(force: true)
  end

  def self.rebalance(n: 10, bail: false, force: false)
    unless force
      usdc = JSON.parse(Iconomi.get('/v1/strategies/DECENTCOOP/structure'))['values'].find { |asset| asset['assetTicker'] == 'USDC' }
      if usdc && usdc['rebalancedWeight'] == 0.9
        puts 'Strategy is in bailed state, exiting'
        return
      end
    end

    Delayed::Job.where(handler: /method_name: :rebalance/).destroy_all

    if bail
      # Mail.deliver do
      #   from 'notifications@stephenreid.net'
      #   to 'stephen@stephenreid.net'
      #   subject "Bailing at $#{JSON.parse(Iconomi.get('/v1/user/balance'))['daaList'].find { |daa| daa['ticker'] == 'DECENTCOOP' }['value'].to_i.to_s.reverse.scan(/\d{3}|.+/).join(',').reverse}"
      # end
      weights = [['USDC', 0.9], ['ETH', 0.1]]
      data = {
        ticker: 'DECENTCOOP',
        values: weights.map do |ticker, p|
          { assetTicker: ticker, rebalancedWeight: p }
        end,
        speedType: 'FAST'
      }
      Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
    else
      # Mail.deliver do
      #   from 'notifications@stephenreid.net'
      #   to 'stephen@stephenreid.net'
      #   subject "Rebalancing at $#{JSON.parse(Iconomi.get('/v1/user/balance'))['daaList'].find { |daa| daa['ticker'] == 'DECENTCOOP' }['value'].to_i.to_s.reverse.scan(/\d{3}|.+/).join(',').reverse}"
      # end
      Strategy.update
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
          speedType: 'SLOW'
        }

        puts n
        puts data.to_json
        begin
          Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
          success = true
        rescue StandardError => e
          puts e
          n -= 1
          raise Strategy::RebalancingError if n < 3
        end
      end
    end
  end
end
