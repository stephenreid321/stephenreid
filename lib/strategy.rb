# A strategy on ICONOMI, fetched with its holdings into data/fetched/iconomi.json (rake data:iconomi). Its status comes
# from data/iconomi/strategies.csv, which you edit by hand. Scores are worked out each time the data is read
class Strategy
  class RoundingError < StandardError; end
  class NotEnoughStrategies < StandardError; end

  MONTH_FACTOR = 4
  THREE_MONTH_FACTOR = 3
  SIX_MONTH_FACTOR = 2
  YEAR_FACTOR = 1

  PERIODS = %w[day week month three_month six_month year].freeze
  FEES = %w[management performance entry exit].freeze
  # What's fetched for each strategy
  FIELDS = (%w[ticker name manager managementType aum numberOfAssets lastRebalanced monthlyRebalancedCount last_posted_at] +
            FEES.map { |r| "#{r}Fee" } + PERIODS.map { |t| "r#{t}" }).freeze
  # What's scored against the other strategies, as nscore_x (0 to 100) and index_x (its rank)
  SCORED = %w[aum rday rweek rmonth rthree_month rsix_month ryear score score_fee_weighted].freeze

  attr_accessor(*FIELDS, :status, :holdings, :score, :score_fee_weighted, *SCORED.flat_map { |x| ["nscore_#{x}", "index_#{x}"] })

  # A holding is { 'ticker' => ..., 'weight' => ... }
  def initialize(attributes = {})
    attributes.each { |name, value| public_send(:"#{name}=", value) if respond_to?(:"#{name}=") }
    self.lastRebalanced = Time.zone.parse(lastRebalanced) if lastRebalanced.is_a?(String)
    self.last_posted_at = Time.zone.parse(last_posted_at) if last_posted_at.is_a?(String)
    self.holdings ||= []
  end

  def self.statuses
    ['', 'verified', 'excluded']
  end

  def verified?
    status == 'verified'
  end

  def attributes
    FIELDS.to_h { |f| [f, public_send(f)] }.merge('holdings' => holdings).transform_values { |v| v.is_a?(Time) ? v.utc.iso8601 : v }
  end

  # Its largest holding: its asset and weight
  def top_holding
    holding = holdings.max_by { |h| h['weight'] }
    [Asset.find_by_ticker(holding['ticker']), holding['weight']] if holding
  end

  def calculate_score
    ((MONTH_FACTOR * (nscore_rmonth || 0)) + (THREE_MONTH_FACTOR * (nscore_rthree_month || 0)) + (SIX_MONTH_FACTOR * (nscore_rsix_month || 0)) + (YEAR_FACTOR * (nscore_ryear || 0)))
  end

  def calculate_score_fee_weighted
    score * (1 - (managementFee || 0)) * (1 - (performanceFee || 0)) * (1 - (entryFee || 0)) * (1 - (exitFee || 0))
  end

  # The strategies' tickers, highest x first and those without one last
  def self.ranked_tickers(strategies, x)
    with, without = strategies.partition { |s| s.public_send(x) }
    (with.sort_by { |s| -s.public_send(x) } + without).map(&:ticker)
  end

  # Scores each of the strategies on each of SCORED, from 0 for the lowest to 100 for the highest, and ranks them
  def self.nscore_index(strategies: active_mature)
    SCORED.each do |x|
      if %w[score score_fee_weighted].include?(x)
        strategies.each do |strategy|
          strategy.public_send("#{x}=", strategy.public_send("calculate_#{x}"))
        end
      end
      tickers = ranked_tickers(strategies, x)
      min, max = strategies.filter_map { |s| s.public_send(x) }.minmax
      strategies.each do |strategy|
        next unless strategy.public_send(x)

        strategy.public_send("nscore_#{x}=", 100 * ((strategy.public_send(x) - min) / (max - min)))
        strategy.public_send("index_#{x}=", tickers.index(strategy.ticker) + 1)
      end
    end
  end

  # Its score on x against the strategies, and its rank
  def nscore_index(x, strategies: Strategy.active_mature)
    tickers = Strategy.ranked_tickers(strategies, x)
    min, max = strategies.filter_map { |s| s.public_send(x) }.minmax
    nscore = 100 * ((public_send(x) - min) / (max - min))
    index = tickers.index(ticker) + 1
    [nscore, index]
  end

  def max_maturity
    m = nil
    %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
      m = r if public_send("r#{r.downcase}")
    end
    m
  end

  # Fetches its fees, size, structure and returns from ICONOMI
  def update
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}"))
    FEES.each do |r|
      public_send("#{r}Fee=", j["#{r}Fee"])
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/price"))
    self.aum = j['aum']
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/posts"))
    if (last_post = j['posts'].max_by { |x| x['timestamp'] })
      self.last_posted_at = Time.at(last_post['timestamp'] / 1000)
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/structure"))
    %w[numberOfAssets lastRebalanced monthlyRebalancedCount].each do |r|
      public_send("#{r}=", (r == 'lastRebalanced' ? Time.at(j[r]) : j[r]))
    end
    self.holdings = j['values'].filter_map do |v|
      { 'ticker' => v['assetTicker'], 'name' => v['assetName'], 'weight' => v['targetWeight'] } if v['assetTicker'].present?
    end
    j = JSON.parse(Iconomi.get("/v1/strategies/#{ticker}/statistics"))
    %w[DAY WEEK MONTH THREE_MONTH SIX_MONTH YEAR].each do |r|
      public_send("r#{r.downcase}=", j['returns'][r])
    end
  end

  class << self
    # Every strategy fetched, scored
    def all
      @all ||= begin
        statuses = csv_file.rows.transform_values { |row| row['status'] }
        Fetched.read(:iconomi, {}).fetch('strategies', []).map do |attributes|
          new(attributes.merge('status' => statuses[attributes['ticker']]))
        end.tap { |strategies| nscore_index(strategies: active_mature(strategies)) }
      end
    end

    def csv_file
      CuratedCsv.new('iconomi/strategies', %w[ticker name status])
    end

    def find_by_ticker(ticker)
      all.find { |strategy| strategy.ticker == ticker }
    end

    def verified
      all.select(&:verified?)
    end

    def reset!
      @all = nil
      Asset.reset!
    end

    # Fetches every strategy on ICONOMI, the assets they hold and Metastrategy's structure into
    # data/fetched/iconomi.json. A strategy that can't be fetched in three attempts is left out
    def fetch
      strategies = JSON.parse(Iconomi.get('/v1/strategies')).map do |s|
        new(s.slice('ticker', 'name', 'manager', 'managementType'))
      end
      count = strategies.count
      strategies = strategies.each_with_index.filter_map do |strategy, i|
        puts "#{i + 1}/#{count}"
        attempts = 0
        begin
          attempts += 1
          strategy.update
          strategy
        rescue StandardError
          if attempts < 3
            puts "error: #{strategy.ticker}, attempt #{attempts + 1}"
            retry
          end
          puts "error: #{strategy.ticker}, leaving it out"
          nil
        end
      end
      assets = strategies.flat_map(&:holdings).to_h { |h| [h['ticker'], h['name']] }
      metastrategy = JSON.parse(Iconomi.get('/v1/strategies/DECENTCOOP/structure'))
      Fetched.write(:iconomi, { 'fetched_at' => Time.now.utc.iso8601, 'strategies' => strategies.map(&:attributes),
                                'assets' => assets, 'metastrategy' => metastrategy })
      reset!
    end

    # Marks the strategies and assets that have no status as verified, in data/iconomi/strategies.csv and
    # data/iconomi/assets.csv, as the old admin page's Verify did. Returns those it marked
    def verify
      fetched = Fetched.read(:iconomi, {})
      changed = csv_file.verify(fetched.fetch('strategies', []).to_h { |s| [s['ticker'], s['name']] }) +
                Asset.csv_file.verify(fetched.fetch('assets', {}))
      reset!
      changed
    end

    # Those that haven't been verified: new ones, and those excluded
    def unverified
      all.reject(&:verified?)
    end

    def active_mature(strategies = all, mature_period: 'THREE_MONTH')
      strategies.select do |s|
        ((s.lastRebalanced && s.lastRebalanced >= 3.months.ago) || (s.last_posted_at && s.last_posted_at >= 3.months.ago) || (s.aum && s.aum >= 500_000)) &&
          !s.public_send(:"r#{mature_period.downcase}").nil? && s.verified?
      end
    end

    # How many assets Metastrategy holds: the NUMBER_OF_ASSETS variable
    def number_of_assets
      Integer(ENV.fetch('NUMBER_OF_ASSETS'))
    rescue KeyError
      raise KeyError, 'Set NUMBER_OF_ASSETS to the number of assets Metastrategy holds'
    end

    def assets_weighted
      with_multipliers = {}
      without_multipliers = {}
      strategies = active_mature.select { |s| s.ticker != 'DECENTCOOP' && s.nscore_score }
      count = strategies.count
      raise Strategy::NotEnoughStrategies, "#{count} active, mature, verified strategies" if count < 50

      strategies.each do |strategy|
        strategy.holdings.each do |holding|
          asset = if %w[USDT TUSD DAI USDC PAXG].include?(holding['ticker'])
                    Asset.find_by_ticker('PAXG')
                  else
                    Asset.find_by_ticker(holding['ticker'])
                  end
          next unless asset.verified?

          ticker = asset.ticker
          with_multipliers[ticker] = 0 unless with_multipliers[ticker]
          without_multipliers[ticker] = 0 unless without_multipliers[ticker]
          with_multipliers[ticker] += holding['weight'] * strategy.nscore_score * (asset.multiplier || 1)
          without_multipliers[ticker] += holding['weight'] * strategy.nscore_score
        end
      end
      [with_multipliers, without_multipliers]
    end

    # The weights Metastrategy would rebalance to, with multipliers and without
    def propose
      with_multipliers, without_multipliers = assets_weighted
      [proposed(with_multipliers).to_h, proposed(without_multipliers).to_h]
    end

    def proposed(assets)
      # restrict to top n assets
      assets = assets.sort_by { |_k, v| -v }[0..(number_of_assets - 1)]
      t = assets.map { |_k, v| v }.sum
      assets = assets.to_h { |k, v| [k, v / t] }

      # make sure asset weights sum to exactly 1
      assets = assets.to_h { |k, v| [k, v.floor(4)] }
      t = assets.map { |_k, v| v }.sum
      k = assets.keys.first
      assets[k] += (1 - t)
      assets[k] = assets[k].round(4)

      t = assets.map { |_k, v| v }.sum
      raise Strategy::RoundingError, assets.to_json unless t == 1

      assets.map { |k, v| [k, v] }
    end

    # Rebalances Metastrategy on ICONOMI to the proposed weights, with multipliers, after fetching the strategies afresh
    def rebalance(skip_update: false)
      fetch unless skip_update

      with_multipliers, _without_multipliers = assets_weighted
      weights = proposed(with_multipliers)

      data = {
        ticker: 'DECENTCOOP',
        values: weights.map do |ticker, p|
          { assetTicker: ticker, rebalancedWeight: p }
        end,
        speedType: 'SLOW'
      }

      puts data.to_json
      puts Iconomi.post('/v1/strategies/DECENTCOOP/structure', data.to_json)
    end
  end
end
