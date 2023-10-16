class Strategy
  include Mongoid::Document
  include Mongoid::Timestamps
  class RoundingError < StandardError; end
  class NotEnoughStrategies < StandardError; end

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
  field :status, type: String
  index({ status: 1 })
  %w[day week month three_month six_month year].each do |t|
    field :"r#{t}", type: Float
    index({ "r#{t}": 1 })
  end
  field :score, type: Float
  index({ score: 1 })
  field :score_fee_weighted, type: Float
  index({ score_fee_weighted: 1 })
  field :aum, type: Float
  index({ aum: 1 })
  %w[aum rday rweek rmonth rthree_month rsix_month ryear score score_fee_weighted].each do |x|
    field :"nscore_#{x}", type: Float
    index({ "nscore_#{x}": 1 })
    field :"index_#{x}", type: Integer
    index({ "index_#{x}": 1 })
  end
  field :last_posted_at, type: Time

  def self.admin_fields
    {
      ticker: :text,
      name: :text,
      score: :number,
      score_fee_weighted: :number,
      aum: :number,
      manager: :text,
      managementType: :text,
      managementFee: :number,
      performanceFee: :number,
      entryFee: :number,
      exitFee: :number,
      numberOfAssets: :number,
      lastRebalanced: :datetime,
      monthlyRebalancedCount: :number,
      last_posted_at: :datetime,
      status: :select,
      holdings: :collection
    }
      .merge(%w[day week month three_month six_month year].map do |t|
               ["r#{t}".to_sym, :number]
             end.to_h)
      .merge(%w[aum rday rweek rmonth rthree_month rsix_month ryear score score_fee_weighted].map do |x|
               [
                 ["nscore_#{x}".to_sym, :number],
                 ["index_#{x}".to_sym, :number]
               ]
             end.flatten(1).to_h)
  end

  has_many :holdings, dependent: :destroy

  validates_presence_of :ticker

  def self.statuses
    ['', 'verified', 'excluded']
  end

  def calculate_score
    ((MONTH_FACTOR * (nscore_rmonth || 0)) + (THREE_MONTH_FACTOR * (nscore_rthree_month || 0)) + (SIX_MONTH_FACTOR * (nscore_rsix_month || 0)) + (YEAR_FACTOR * (nscore_ryear || 0)))
  end

  def calculate_score_fee_weighted
    score * (1 - (managementFee || 0)) * (1 - (performanceFee || 0)) * (1 - (entryFee || 0)) * (1 - (exitFee || 0))
  end

  def self.nscore_index(strategies: Strategy.active_mature)
    %w[aum rday rweek rmonth rthree_month rsix_month ryear score score_fee_weighted].each do |x|
      if %w[score score_fee_weighted].include?(x)
        strategies.all.each do |strategy|
          strategy.send("#{x}=", strategy.send("calculate_#{x}"))
          strategy.save
        end
      end
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
    %w[management performance entry exit].each do |r|
      send("#{r}Fee=", j["#{r}Fee"])
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/price"))
    self.aum = j['aum']
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/posts"))
    if (last_post = j['posts'].sort_by { |x| x['timestamp'] }.last)
      self.last_posted_at = Time.at(last_post['timestamp'] / 1000)
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/structure"))
    %w[numberOfAssets lastRebalanced monthlyRebalancedCount].each do |r|
      send("#{r}=", (r == 'lastRebalanced' ? Time.at(j[r]) : j[r]))
    end
    j['values'].each do |v|
      asset = Asset.find_or_create_by(ticker: (v['assetTicker'] unless v['assetTicker'].blank?))
      if asset.persisted?
        asset.update_attribute(:name, v['assetName'])
        holdings.create(asset: asset, weight: v['targetWeight'])
      end
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/statistics"))
    %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
      send("r#{r.downcase}=", j['returns'][r])
    end
    save
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
    count = Strategy.all.count
    Strategy.all.each_with_index do |strategy, i|
      puts "#{i + 1}/#{count}"
      begin
        strategy.update
      rescue StandardError
        begin
          puts "error: #{strategy.ticker}, attempt 2"
          strategy.update
        rescue StandardError
          begin
            puts "error: #{strategy.ticker}, attempt 3"
            strategy.update
          rescue StandardError => e
            puts "error: #{strategy.ticker}, deleting"
            strategy.destroy
            Airbrake.notify(e)
          end
        end
      end
    end
    Strategy.nscore_index
  end

  def self.active_mature(mature_period: 'THREE_MONTH')
    self.or({ :monthlyRebalancedCount.gte => 1 }, { :last_posted_at.gte => 1.month.ago }).and(:"r#{mature_period.downcase}".ne => nil, :status => 'verified')
  end

  def self.assets_weighted
    with_multipliers = {}
    without_multipliers = {}
    strategies = Strategy.active_mature.and(:ticker.ne => 'DECENTCOOP', :nscore_score.ne => nil)
    count = strategies.count
    raise Strategy::NotEnoughStrategies if count < 50

    strategies.each_with_index do |strategy, i|
      puts "#{i + 1}/#{count}"
      strategy.holdings.each do |holding|
        asset = if %w[USDT TUSD DAI USDC PAXG].include?(holding.asset.ticker)
                  Asset.find_by(ticker: 'PAXG')
                else
                  holding.asset
                end
        next unless asset.status == 'verified'

        ticker = asset.ticker
        with_multipliers[ticker] = 0 unless with_multipliers[ticker]
        without_multipliers[ticker] = 0 unless without_multipliers[ticker]
        with_multipliers[ticker] += holding.weight * strategy.nscore_score * (asset.multiplier || 1)
        without_multipliers[ticker] += holding.weight * strategy.nscore_score
      end
    end
    [with_multipliers, without_multipliers]
  end

  def self.propose_and_stash
    with_multipliers, without_multipliers = Strategy.assets_weighted
    proposed_with_multipliers = Strategy.proposed(with_multipliers)
    proposed_without_multipliers = Strategy.proposed(without_multipliers)
    Stash.find_by(key: 'proposed_with_multipliers').try(:destroy)
    Stash.create(key: 'proposed_with_multipliers', value: proposed_with_multipliers.to_h.to_json)
    Stash.find_by(key: 'proposed_without_multipliers').try(:destroy)
    Stash.create(key: 'proposed_without_multipliers', value: proposed_without_multipliers.to_h.to_json)
  end

  def self.proposed(assets)
    # restrict to top n assets
    assets = assets.sort_by { |_k, v| -v }[0..(Stash.find_by(key: 'number_of_assets').value.to_i - 1)]
    t = assets.map { |_k, v| v }.sum
    assets = assets.map { |k, v| [k, v / t] }.to_h

    # make sure asset weights sum to exactly 1
    assets = assets.map { |k, v| [k, v.floor(4)] }.to_h
    t = assets.map { |_k, v| v }.sum
    k = assets.keys.first
    assets[k] += (1 - t)
    assets[k] = assets[k].round(4)

    t = assets.map { |_k, v| v }.sum
    raise Strategy::RoundingError, assets.to_json unless t == 1

    assets.map { |k, v| [k, v] }
  end

  def self.rebalance(skip_update: false)
    Delayed::Job.and(handler: /method_name: :rebalance/).destroy_all

    Strategy.update unless skip_update

    with_multipliers, _without_multipliers = Strategy.assets_weighted
    weights = Strategy.proposed(with_multipliers)

    data = {
      ticker: 'DECENTCOOP',
      values: weights.map do |ticker, p|
        { assetTicker: ticker, rebalancedWeight: p }
      end,
      speedType: 'SLOW'
    }

    puts data.to_json
    Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
  end
end
