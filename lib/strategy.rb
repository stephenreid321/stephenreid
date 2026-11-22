# A strategy on ICONOMI, fetched with its holdings into data/fetched/iconomi.json (rake data:iconomi). Its status comes
# from data/iconomi/strategies.csv, which you edit by hand. Scores are worked out each time the data is read
require_relative 'curated_csv'

class Strategy
  include Curated

  class NotEnoughStrategies < StandardError; end

  # Metastrategy, Stephen's strategy on ICONOMI
  METASTRATEGY = 'DECENTCOOP'.freeze
  CSV_COLUMNS = %w[ticker name status].freeze
  # How much each period's return counts towards a strategy's score
  SCORE_FACTORS = { 'rmonth' => 4, 'rthree_month' => 3, 'rsix_month' => 2, 'ryear' => 1 }.freeze
  # Stablecoins, which Metastrategy holds as PAXG
  STABLECOINS = %w[USDT TUSD DAI USDC].freeze
  # The fewest active, mature, verified strategies Metastrategy is worked out from
  MIN_STRATEGIES = 50

  PERIODS = %w[day week month three_month six_month year].freeze
  FEES = %w[management performance entry exit].freeze
  # What's fetched for each strategy
  FIELDS = (%w[ticker name manager managementType aum numberOfAssets lastRebalanced monthlyRebalancedCount last_posted_at] +
            FEES.map { |r| "#{r}Fee" } + PERIODS.map { |t| "r#{t}" }).freeze
  # Days ICONOMI rebalanced every strategy itself, which don't show a strategy's still managed
  PLATFORM_REBALANCE_DATES = [Date.new(2026, 8, 26)].freeze
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

  def attributes
    FIELDS.to_h { |f| [f, public_send(f)] }.merge('holdings' => holdings).transform_values { |v| v.is_a?(Time) ? v.utc.iso8601 : v }
  end

  # Its largest holding: its asset and weight
  def top_holding
    holding = holdings.max_by { |h| h['weight'] }
    [Asset.find_by_ticker(holding['ticker']), holding['weight']] if holding
  end

  # When its manager last rebalanced it: lastRebalanced, unless that was one of ICONOMI's own
  def managed_rebalanced_at
    lastRebalanced unless lastRebalanced && PLATFORM_REBALANCE_DATES.include?(lastRebalanced.utc.to_date)
  end

  def calculate_score
    SCORE_FACTORS.sum { |x, factor| factor * (public_send("nscore_#{x}") || 0) }
  end

  def calculate_score_fee_weighted
    FEES.inject(score) { |weighted, fee| weighted * (1 - (public_send("#{fee}Fee") || 0)) }
  end

  # Each strategy that has an x: its score on it against the others', from 0 for the lowest to 100 for the highest (100
  # if they're all the same, or it's the only one), and its rank, highest first
  def self.nscores(strategies, x)
    ranked = strategies.select { |s| s.public_send(x) }.sort_by { |s| -s.public_send(x) }
    max = ranked.first&.public_send(x)
    min = ranked.last&.public_send(x)
    ranked.each_with_index.to_h do |s, i|
      [s, [max == min ? 100.0 : 100 * ((s.public_send(x) - min) / (max - min)), i + 1]]
    end
  end

  # Scores each of the strategies on each of SCORED and ranks them, as nscore_x and index_x
  def self.score_and_rank(strategies)
    SCORED.each do |x|
      strategies.each { |s| s.public_send("#{x}=", s.public_send("calculate_#{x}")) } if %w[score score_fee_weighted].include?(x)
      nscores(strategies, x).each do |strategy, (nscore, index)|
        strategy.public_send("nscore_#{x}=", nscore)
        strategy.public_send("index_#{x}=", index)
      end
    end
  end

  # Its score on x against the strategies, and its rank; nil if it has no x
  def nscore_index(x, strategies: Strategy.active_mature)
    Strategy.nscores(strategies, x)[self]
  end

  # Fetches its name, manager, fees, size, structure and returns from ICONOMI
  def update
    j = Iconomi.get_json("/v1/strategies/#{ticker}")
    (%w[name manager managementType] + FEES.map { |fee| "#{fee}Fee" }).each { |r| public_send("#{r}=", j[r]) }
    self.aum = Iconomi.get_json("/v1/strategies/#{ticker}/price")['aum']
    if (last_post = Iconomi.get_json("/v1/strategies/#{ticker}/posts")['posts'].max_by { |x| x['timestamp'] })
      self.last_posted_at = Time.at(last_post['timestamp'] / 1000)
    end
    j = Iconomi.get_json("/v1/strategies/#{ticker}/structure")
    self.numberOfAssets, self.monthlyRebalancedCount = j.values_at('numberOfAssets', 'monthlyRebalancedCount')
    self.lastRebalanced = Time.at(j['lastRebalanced'])
    self.holdings = j['values'].filter_map do |v|
      { 'ticker' => v['assetTicker'], 'name' => v['assetName'], 'weight' => v['targetWeight'] } if v['assetTicker'].present?
    end
    returns = Iconomi.get_json("/v1/strategies/#{ticker}/statistics")['returns']
    PERIODS.each { |t| public_send("r#{t}=", returns[t.upcase]) }
  end

  class << self
    # Every strategy fetched, scored
    def all
      @all ||= begin
        statuses = csv_file.rows.transform_values { |row| row['status'] }
        Fetched.read(:iconomi, {}).fetch('strategies', []).map do |attributes|
          new(attributes.merge('status' => statuses[attributes['ticker']]))
        end.tap { |strategies| score_and_rank(active_mature(strategies)) }
      end
    end

    def find_by_ticker(ticker)
      all.find { |strategy| strategy.ticker == ticker }
    end

    def verified
      all.select(&:verified?)
    end

    def reset!
      super
      Asset.reset!
    end

    # Fetches, as fetch does, unless ICN_API_KEY isn't set (as for a fork, or here without the keys): then says so, and
    # leaves data/fetched as it is. For rake data:iconomi. Not for a rebalance, which fails without them
    def fetch_if_keys
      return puts 'ℹ️  ICONOMI fetch skipped: set ICN_API_KEY and ICN_SECRET.' if ENV['ICN_API_KEY'].blank?

      fetch
    end

    # Fetches every strategy on ICONOMI, the assets they hold and Metastrategy's structure into
    # data/fetched/iconomi.json, a few at a time. A strategy that can't be fetched is left out
    def fetch(threads: 8)
      queue = Queue.new
      tickers.each { |ticker| queue << ticker }
      count = queue.size
      queue.close
      fetched = Array.new(threads) do
        Thread.new do
          done = []
          while (ticker = queue.pop)
            strategy = fetch_one(ticker)
            done << strategy if strategy
          end
          done
        end
      end.flat_map(&:value)
      puts "Fetched #{fetched.count} of #{count} strategies"
      strategies = fetched.sort_by(&:ticker)
      assets = strategies.flat_map(&:holdings).to_h { |h| [h['ticker'], h['name']] }
      metastrategy = Iconomi.get_json("/v1/strategies/#{METASTRATEGY}/structure")
      Fetched.write(:iconomi, { 'fetched_at' => Time.now.utc.iso8601, 'strategies' => strategies.map(&:attributes),
                                'assets' => assets, 'metastrategy' => metastrategy })
      reset!
    end

    # Each strategy's ticker: those ICONOMI lists, those its site scores (unlisted ones too), and those in
    # data/iconomi/strategies.csv. Without the site's, if its websocket fails, just the others
    def tickers
      listed = Iconomi.get_json('/v1/strategies').pluck('ticker')
      scored = begin
        Iconomi.strategy_tickers
      rescue StandardError => e
        puts "⚠️  ICONOMI's site didn't list its strategies (#{e.message}), so fetching only those listed and in data/iconomi/strategies.csv"
        []
      end
      (listed | scored | csv_file.rows.keys).compact
    end

    # The strategy with this ticker, fetched from ICONOMI, or nil if it can't be (Iconomi.get has tried again what
    # might work a second time)
    def fetch_one(ticker)
      new('ticker' => ticker).tap(&:update)
    rescue StandardError => e
      puts "error: #{ticker}, leaving it out (#{e.message[0, 300]})"
      nil
    end

    # Marks the strategies and assets that have no status as verified, in data/iconomi/strategies.csv and
    # data/iconomi/assets.csv, as the old admin page's Verify did. Says which, and returns them
    def verify
      fetched = Fetched.read(:iconomi, {})
      changed = csv_file.verify(fetched.fetch('strategies', []).to_h { |s| [s['ticker'], s['name']] }) +
                Asset.csv_file.verify(fetched.fetch('assets', {}))
      reset!
      puts "Verified: #{changed.join(', ').presence || 'nothing new'}"
      changed
    end

    def active_mature(strategies = all, mature_period: 'THREE_MONTH')
      strategies.select do |s|
        ((s.managed_rebalanced_at && s.managed_rebalanced_at >= 3.months.ago) || (s.last_posted_at && s.last_posted_at >= 3.months.ago) || (s.aum && s.aum >= 500_000)) &&
          !s.public_send(:"r#{mature_period.downcase}").nil? && s.verified?
      end
    end

    # How many assets Metastrategy holds: the NUMBER_OF_ASSETS variable
    def number_of_assets
      Integer(ENV.fetch('NUMBER_OF_ASSETS'))
    rescue KeyError
      raise KeyError, 'Set NUMBER_OF_ASSETS to the number of assets Metastrategy holds'
    end

    # Each verified asset the strategies Metastrategy is worked out from hold, weighted by how much they hold of it and
    # how well they score: with its multiplier, and without
    def assets_weighted
      strategies = active_mature.select { |s| s.ticker != METASTRATEGY && s.nscore_score }
      raise Strategy::NotEnoughStrategies, "#{strategies.count} active, mature, verified strategies" if strategies.count < MIN_STRATEGIES

      with_multipliers = Hash.new(0)
      without_multipliers = Hash.new(0)
      strategies.each do |strategy|
        strategy.holdings.each do |holding|
          asset = Asset.find_by_ticker(STABLECOINS.include?(holding['ticker']) ? 'PAXG' : holding['ticker'])
          next unless asset.verified?

          weight = holding['weight'] * strategy.nscore_score
          with_multipliers[asset.ticker] += weight * (asset.multiplier || 1)
          without_multipliers[asset.ticker] += weight
        end
      end
      [with_multipliers, without_multipliers]
    end

    # The weights Metastrategy would rebalance to, with multipliers and without
    def propose
      with_multipliers, without_multipliers = assets_weighted
      [proposed(with_multipliers).to_h, proposed(without_multipliers).to_h]
    end

    # The top number_of_assets assets, weighted in proportion. In whole basis points, each rounded down with what's
    # left over going to the largest, so they sum to exactly 1
    def proposed(assets)
      top = assets.sort_by { |_k, v| -v }.first(number_of_assets)
      total = top.sum { |_k, v| v }
      basis_points = top.to_h { |k, v| [k, (10_000 * v / total).floor] }
      basis_points[top.first.first] += 10_000 - basis_points.values.sum
      basis_points.map { |k, bp| [k, bp / 10_000.0] }
    end

    # Rebalances Metastrategy on ICONOMI to the proposed weights, with multipliers, after fetching the strategies afresh
    def rebalance(skip_update: false)
      fetch unless skip_update

      with_multipliers, _without_multipliers = assets_weighted
      weights = proposed(with_multipliers)

      data = {
        ticker: METASTRATEGY,
        values: weights.map { |ticker, weight| { assetTicker: ticker, rebalancedWeight: weight } },
        speedType: 'SLOW'
      }

      puts data.to_json
      puts Iconomi.post("/v1/strategies/#{METASTRATEGY}/structure", data.to_json)
    end
  end
end
