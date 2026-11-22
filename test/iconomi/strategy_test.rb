require 'test_config'
require 'helpers/iconomi_helpers'

class IconomiStrategyTest < ActiveSupport::TestCase
  include IconomiHelpers

  test 'scores each return from 0 for the lowest to 100 for the highest, and ranks them' do
    low = strategy_attributes('LOW', rmonth: 0.0, rthree_month: 0.0, rsix_month: 0.0, ryear: 0.0)
    mid = strategy_attributes('MID', rmonth: 0.5, rthree_month: 0.2, rsix_month: 1.0, ryear: 0.0)
    high = strategy_attributes('HIGH', rmonth: 1.0, rthree_month: 0.4, rsix_month: 2.0, ryear: 1.0)
    with_iconomi([low, mid, high]) do
      strategy = Strategy.find_by_ticker('MID')

      assert_in_delta 50, strategy.nscore_rmonth
      assert_equal 2, strategy.index_rmonth
      assert_in_delta 0, Strategy.find_by_ticker('LOW').nscore_rmonth
      assert_in_delta 100, Strategy.find_by_ticker('HIGH').nscore_rmonth
      # The month counts 4 times, three months 3, six months 2 and the year once
      assert_in_delta (4 * 50) + (3 * 50) + (2 * 50) + (1 * 0), strategy.score
      assert_equal %w[HIGH MID LOW], Strategy.active_mature.sort_by(&:index_score).map(&:ticker)
    end
  end

  test "a strategy that's the only one with a return, or one of those all the same, scores 100 on it" do
    alone = strategy_attributes('ALONE', ryear: 0.3)
    with_iconomi([alone, strategy_attributes('YOUNG', ryear: nil, aum: alone['aum']), strategy_attributes('SAME', aum: alone['aum'])]) do
      assert_in_delta 100, Strategy.find_by_ticker('ALONE').nscore_ryear
      assert_nil Strategy.find_by_ticker('YOUNG').nscore_ryear
      assert_equal([100.0] * 3, %w[ALONE YOUNG SAME].map { |t| Strategy.find_by_ticker(t).nscore_aum })
    end
  end

  test 'weights the score down by each fee' do
    plain = strategy_attributes('PLAIN', rmonth: 1.0)
    fees = strategy_attributes('FEES', rmonth: 1.0, rthree_month: 1.0, rsix_month: 1.0, ryear: 1.0, managementFee: 0.02, performanceFee: 0.2, entryFee: 0.01, exitFee: 0.005)
    with_iconomi([plain, fees, strategy_attributes('LOW', rmonth: 0.0)]) do
      assert_in_delta Strategy.find_by_ticker('PLAIN').score, Strategy.find_by_ticker('PLAIN').score_fee_weighted
      fees = Strategy.find_by_ticker('FEES')

      assert_in_delta fees.score * 0.98 * 0.8 * 0.99 * 0.995, fees.score_fee_weighted
    end
  end

  test 'scores only the active, mature, verified strategies' do
    stale = strategy_attributes('STALE', lastRebalanced: 4.months.ago.utc.iso8601)
    large = strategy_attributes('LARGE', lastRebalanced: 4.months.ago.utc.iso8601, aum: 600_000)
    posting = strategy_attributes('POSTING', lastRebalanced: 4.months.ago.utc.iso8601, last_posted_at: 1.week.ago.utc.iso8601)
    young = strategy_attributes('YOUNG', rthree_month: nil, rsix_month: nil, ryear: nil)
    # ICONOMI rebalanced every strategy itself that day, which doesn't show anyone's managing it
    platform = strategy_attributes('PLATFORM', lastRebalanced: Time.utc(2026, 8, 26, 12).iso8601)

    with_iconomi([stale, large, posting, young, platform, strategy_attributes('UNVERIFIED'), strategy_attributes('OK')],
                 verified: %w[STALE LARGE POSTING YOUNG PLATFORM OK]) do
      assert_equal %w[LARGE OK POSTING], Strategy.active_mature.map(&:ticker).sort
    end
  end

  test 'proposes the top assets, weighted by the strategies that hold them, in whole basis points that sum to 1' do
    strategies = many_strategies + [strategy_attributes('DOGEY', holdings: { 'DOGE' => 1.0 }, rmonth: 1.0)]
    with_iconomi(strategies) do
      with_env('NUMBER_OF_ASSETS' => '2') do
        proposed, without_multipliers = Strategy.propose

        # DOGE isn't verified, so it's left out however well its strategy does
        assert_equal %w[BTC ETH], proposed.keys
        assert_equal proposed, without_multipliers
        assert_in_delta 0.625, proposed['BTC']
        assert_in_delta 0.375, proposed['ETH']
        assert_equal(10_000, proposed.values.sum { |w| (w * 10_000).round })
      end
    end
  end

  test 'counts the stablecoins as PAXG' do
    strategies = many_strategies.map { |s| s.merge('holdings' => [{ 'ticker' => 'USDT', 'name' => 'Tether', 'weight' => 1.0 }]) }
    with_iconomi(strategies) do
      with_env('NUMBER_OF_ASSETS' => '5') { assert_equal({ 'PAXG' => 1.0 }, Strategy.propose.first) }
    end
  end

  test 'a multiplier weights an asset up in the proposal, but not in the one without multipliers' do
    with_iconomi(many_strategies, multipliers: { 'PAXG' => 3 }) do
      with_env('NUMBER_OF_ASSETS' => '3') do
        proposed, without_multipliers = Strategy.propose

        assert_in_delta 0.2, without_multipliers['PAXG']
        assert_in_delta 0.6 / 1.4, proposed['PAXG'], 0.0002
      end
    end
  end

  test 'refuses to propose from fewer than 50 strategies' do
    with_iconomi(many_strategies(49)) do
      with_env('NUMBER_OF_ASSETS' => '3') do
        error = assert_raises(Strategy::NotEnoughStrategies) { Strategy.propose }
        assert_match(/49 active, mature, verified strategies/, error.message)
      end
    end
  end

  test 'says to set NUMBER_OF_ASSETS when it is missing' do
    with_iconomi(many_strategies) do
      with_env('NUMBER_OF_ASSETS' => nil) do
        assert_match(/Set NUMBER_OF_ASSETS/, assert_raises(KeyError) { Strategy.propose }.message)
      end
    end
  end

  test 'rebalances Metastrategy to the proposal, signed with ICN_SECRET' do
    posted = nil
    stub_http do |stub|
      stub.post('https://api.iconomi.com/v1/strategies/DECENTCOOP/structure') do |env|
        posted = env
        [200, {}, '{}']
      end
    end
    with_iconomi(many_strategies) do
      with_env('NUMBER_OF_ASSETS' => '2', 'ICN_API_KEY' => 'key', 'ICN_SECRET' => 'secret') do
        capture_io { Strategy.rebalance(skip_update: true) }
      end
    end

    body = JSON.parse(posted.request_body)

    assert_equal %w[DECENTCOOP SLOW], body.values_at('ticker', 'speedType')
    assert_equal %w[BTC ETH], body['values'].pluck('assetTicker')
    assert_in_delta 0.625, body['values'][0]['rebalancedWeight']
    assert_in_delta(1, body['values'].sum { |v| v['rebalancedWeight'] })
    timestamp = posted.request_headers['ICN-TIMESTAMP']
    signature = [OpenSSL::HMAC.digest('sha512', 'secret', "#{timestamp}POST/v1/strategies/DECENTCOOP/structure#{posted.request_body}")].pack('m0')

    assert_equal 'key', posted.request_headers['ICN-API-KEY']
    assert_equal signature, posted.request_headers['ICN-SIGN']
  end

  test 'a rebalance ICONOMI refuses fails' do
    stub_http { |stub| stub.post('https://api.iconomi.com/v1/strategies/DECENTCOOP/structure') { [400, {}, 'no'] } }
    with_iconomi(many_strategies) do
      with_env('NUMBER_OF_ASSETS' => '2') do
        error = assert_raises(RuntimeError) { capture_io { Strategy.rebalance(skip_update: true) } }

        assert_match(/HTTP 400/, error.message)
      end
    end
  end

  test 'fetches every strategy, leaving out one it cannot, with the assets they hold and Metastrategy' do
    stub_http do |stub|
      stub.get('https://api.iconomi.com/v1/strategies') { json([{ 'ticker' => 'ONE' }]) }
      %w[ONE DECENTCOOP].each do |ticker|
        stub.get("https://api.iconomi.com/v1/strategies/#{ticker}") { json('name' => "#{ticker} name", 'manager' => 'm', 'managementType' => 'x', 'managementFee' => 0.02) }
        stub.get("https://api.iconomi.com/v1/strategies/#{ticker}/price") { json('aum' => 5000) }
        stub.get("https://api.iconomi.com/v1/strategies/#{ticker}/posts") { json('posts' => [{ 'timestamp' => 1_700_000_000_000 }]) }
        stub.get("https://api.iconomi.com/v1/strategies/#{ticker}/structure") do
          json('numberOfAssets' => 1, 'lastRebalanced' => 1_700_000_000, 'monthlyRebalancedCount' => 2,
               'values' => [{ 'assetTicker' => 'BTC', 'assetName' => 'Bitcoin', 'targetWeight' => 1.0, 'rebalancedWeight' => 1.0 }])
        end
        stub.get("https://api.iconomi.com/v1/strategies/#{ticker}/statistics") { json('returns' => { 'DAY' => 0.01, 'YEAR' => 0.5 }) }
      end
      # Its holdings are private
      stub.get('https://api.iconomi.com/v1/strategies/PRIVATE') { [401, {}, 'Unauthorized'] }
    end

    written = nil
    out = Iconomi.stub(:throttle, nil) do
      Iconomi.stub(:strategy_tickers, %w[DECENTCOOP PRIVATE]) do
        Strategy.stub(:csv_file, curated_csv('iconomi/strategies', %w[ticker name status])) do
          capture_io { written = fetched_after { Strategy.fetch(threads: 2) } }.first
        end
      end
    end

    assert_match(/Fetched 2 of 3 strategies/, out)
    iconomi = written['iconomi']

    assert_equal %w[DECENTCOOP ONE], iconomi['strategies'].pluck('ticker')
    one = iconomi['strategies'].last

    assert_equal ['ONE name', 0.02, 5000, 0.5, Time.at(1_700_000_000).utc.iso8601], one.values_at('name', 'managementFee', 'aum', 'ryear', 'lastRebalanced')
    assert_equal({ 'BTC' => 'Bitcoin' }, iconomi['assets'])
    assert_equal 'BTC', iconomi.dig('metastrategy', 'values', 0, 'assetTicker')
  end

  test 'marks the strategies and assets with no status as verified, leaving those with one' do
    strategies_csv = curated_csv('iconomi/strategies', %w[ticker name status], 'OLD' => { 'name' => 'Old', 'status' => 'excluded' })
    assets_csv = curated_csv('iconomi/assets', %w[ticker name status color])
    fetched = { 'strategies' => [{ 'ticker' => 'OLD', 'name' => 'Old' }, { 'ticker' => 'NEW', 'name' => 'New' }], 'assets' => { 'BTC' => 'Bitcoin' } }
    changed = nil
    with_fetched(iconomi: fetched) do
      Strategy.stub(:csv_file, strategies_csv) { Asset.stub(:csv_file, assets_csv) { changed = Strategy.verify } }
    end

    assert_equal %w[NEW BTC], changed
    assert_equal({ 'OLD' => 'excluded', 'NEW' => 'verified' }, strategies_csv.rows.transform_values { |r| r['status'] })
    assert_equal({ 'ticker' => 'BTC', 'name' => 'Bitcoin', 'status' => 'verified', 'color' => nil }, assets_csv.rows['BTC'])
  end
end
