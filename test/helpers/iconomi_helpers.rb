# Strategies, assets and their CSVs for the ICONOMI tests
module IconomiHelpers
  # A CSV of data/iconomi/ with these rows, by ticker, in a temporary folder
  def curated_csv(name, columns, rows = {})
    dir = Dir.mktmpdir
    csv = CuratedCsv.new(name, columns, dir: dir)
    FileUtils.mkdir_p(File.dirname(csv.path))
    csv.write(rows.to_h { |ticker, row| [ticker, { 'ticker' => ticker }.merge(row)] })
    csv
  end

  # A strategy as data/fetched/iconomi.json holds it: active (rebalanced last week), mature, and holding these
  # { ticker => weight }. Its size and returns differ a little from one ticker to the next, as no two strategies' are
  # the same
  def strategy_attributes(ticker, holdings: { 'BTC' => 1.0 }, **attributes)
    {
      'ticker' => ticker, 'name' => "#{ticker} strategy", 'aum' => 1000 + ticker.sum, 'numberOfAssets' => holdings.size,
      'lastRebalanced' => 1.week.ago.utc.iso8601, 'monthlyRebalancedCount' => 4,
      **Strategy::PERIODS.to_h { |t| ["r#{t}", ticker.sum * 0.0001] },
      'holdings' => holdings.map { |t, w| { 'ticker' => t, 'name' => "#{t} coin", 'weight' => w } }
    }.merge(attributes.transform_keys(&:to_s))
  end

  # Runs the block with ICONOMI fetched as these strategies, those verified in data/iconomi/strategies.csv (all of
  # them, unless given), these assets verified in assets.csv, these multipliers, and Metastrategy's structure
  def with_iconomi(strategies, verified: strategies.pluck('ticker'), assets: %w[BTC ETH PAXG], multipliers: {}, metastrategy: nil, &)
    strategies_csv = curated_csv('iconomi/strategies', %w[ticker name status], verified.to_h { |t| [t, { 'status' => 'verified' }] })
    assets_csv = curated_csv('iconomi/assets', %w[ticker name status color], assets.to_h { |t| [t, { 'status' => 'verified' }] })
    multipliers_csv = curated_csv('iconomi/multipliers', %w[ticker name multiplier], multipliers.to_h { |t, m| [t, { 'multiplier' => m.to_s }] })
    names = strategies.flat_map { |s| s['holdings'] }.to_h { |h| [h['ticker'], h['name']] }
    with_fetched(iconomi: { 'strategies' => strategies, 'assets' => names, 'metastrategy' => metastrategy }.compact) do
      IconomiPages.reset!
      Strategy.stub(:csv_file, strategies_csv) do
        Asset.stub(:csv_file, assets_csv) { Asset.stub(:multipliers_file, multipliers_csv, &) }
      end
    end
  end

  # count strategies, each holding BTC, ETH and PAXG, with returns rising strategy by strategy
  def many_strategies(count = 50)
    Array.new(count) do |i|
      strategy_attributes("S#{i}", holdings: { 'BTC' => 0.5, 'ETH' => 0.3, 'PAXG' => 0.2 },
                                   rmonth: i * 0.01, rthree_month: i * 0.02, rsix_month: i * 0.03, ryear: i * 0.04)
    end
  end
end
