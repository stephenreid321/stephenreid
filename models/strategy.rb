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
  index({ ticker: 1 })
  field :name, type: String
  field :manager, type: String
  field :managementType, type: String
  %w[management performance entry exit].each do |r|
    field :"#{r}Fee", type: Float
  end
  field :numberOfAssets, type: Integer
  field :lastRebalanced, type: Time
  field :monthlyRebalancedCount, type: Integer
  field :verified, type: Boolean
  index({ verified: 1 })
  field :excluded, type: Boolean
  index({ excluded: 1 })
  %w[day week month three_month six_month year].each do |t|
    field :"r#{t}", type: Float
    index({ "r#{t}": 1 })
  end
  field :score, type: Float
  index({ score: 1 })
  field :score_fee_weighted, type: Float
  index({ score_fee_weighted: 1 })
  %w[score score_fee_weighted rday rweek rmonth rthree_month rsix_month ryear].each do |x|
    field :"nscore_#{x}", type: Float
    index({ "nscore_#{x}": 1 })
    field :"index_#{x}", type: Integer
    index({ "index_#{x}": 1 })
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
      verified: :check_box,
      excluded: :check_box,
      holdings: :collection
    }
      .merge(Hash[%w[day week month three_month six_month year].map do |t|
                    ["r#{t}".to_sym, :number]
                  end])
      .merge(Hash[%w[score score_fee_weighted rday rweek rmonth rthree_month rsix_month ryear].map do |x|
                    [
                      ["nscore_#{x}".to_sym, :number],
                      ["index_#{x}".to_sym, :number]
                    ]
                  end.flatten(1)])
  end

  has_many :holdings, dependent: :destroy

  validates_presence_of :ticker

  before_validation do
    self.score = calculate_score
    self.score_fee_weighted = calculate_score_fee_weighted
  end

  def calculate_score
    ((MONTH_FACTOR * (rmonth || 0)) + (THREE_MONTH_FACTOR * (rthree_month || 0)) + (SIX_MONTH_FACTOR * (rsix_month || 0)) + (YEAR_FACTOR * (ryear || 0)))
  end

  def calculate_score_fee_weighted
    score * (1 - (managementFee || 0)) * (1 - (performanceFee || 0)) * (1 - (entryFee || 0)) * (1 - (exitFee || 0))
  end

  def self.nscore_index(strategies: Strategy.active_mature)
    %w[score score_fee_weighted rday rweek rmonth rthree_month rsix_month ryear].each do |x|
      Strategy.all.set("nscore_#{x}": nil)
      Strategy.all.set("index_#{x}": nil)
      puts x
      tickers = strategies.order("#{x} desc").pluck(:ticker)
      min = strategies.pluck(x).compact.min
      max = strategies.pluck(x).compact.max
      strategies.each do |strategy|
        next unless strategy.send(x)

        nscore = 100 * ((strategy.send(x) - min) / (max - min))
        index = tickers.index(strategy.ticker) + 1
        strategy.send("nscore_#{x}=", nscore)
        strategy.send("index_#{x}=", index)
        strategy.save
      end
    end
  end

  def nscore_index(x, strategies: Strategy.active_mature)
    tickers = strategies.order("#{x} desc").pluck(:ticker)
    min = strategies.pluck(x).compact.min
    max = strategies.pluck(x).compact.max
    nscore = 100 * ((send(x) - min) / (max - min))
    index = tickers.index(ticker) + 1
    [nscore, index]
  end

  def max_maturity
    m = nil
    %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
      m = r if send("r#{r.downcase}")
    end
    m
  end

  def update
    holdings.delete_all
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}"))
    if j.nil?
      puts "nil response: #{ticker}"
      destroy
      return
    else
      puts ticker
    end
    %w[management performance entry exit].each do |r|
      send("#{r}Fee=", j["#{r}Fee"])
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/structure"))
    %w[numberOfAssets lastRebalanced monthlyRebalancedCount].each do |r|
      send("#{r}=", (r == 'lastRebalanced' ? Time.at(j[r]) : j[r]))
    end
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
  rescue StandardError => e
    # Airbrake.notify(e)
    puts "error: #{ticker}"
    destroy
  end

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
    Strategy.nscore_index
  end

  def self.unverified
    where(:verified.ne => true)
  end

  def self.active_mature(mature_period: 'THREE_MONTH')
    where(:monthlyRebalancedCount.gte => 1, :"r#{mature_period.downcase}".ne => nil, :verified => true)
  end

  def self.proposed(n: 10)
    assets = {}
    count = Strategy.active_mature.and(:ticker.ne => 'DECENTCOOP').count
    Strategy.active_mature.and(:ticker.ne => 'DECENTCOOP').each_with_index do |strategy, i|
      puts "#{i + 1}/#{count}"
      strategy.holdings.each do |holding|
        next unless holding.asset.verified

        ticker = holding.asset.ticker
        assets[ticker] = 0 unless assets[ticker]
        assets[ticker] += holding.weight * strategy.score * (holding.asset.multiplier || 1)
      end
    end

    %w[USDT TUSD DAI].each do |s|
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

    # make sure asset weights sum to exactly 1
    assets = Hash[assets.map { |k, v| [k, v.floor(4)] }]
    t = assets.map { |_k, v| v }.sum
    k = assets.keys.first
    assets[k] += (1 - t)
    assets[k] = assets[k].round(4)

    t = assets.map { |_k, v| v }.sum
    raise Strategy::RoundingError(assets.to_json) unless t == 1

    assets.map { |k, v| [k, v] }
  end

  def self.rebalance(n: 10)
    Delayed::Job.and(handler: /method_name: :rebalance/).destroy_all

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
