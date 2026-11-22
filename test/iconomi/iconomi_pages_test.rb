require 'test_config'
require 'helpers/iconomi_helpers'

class IconomiPagesTest < ActiveSupport::TestCase
  include IconomiHelpers

  test "the evaluator's table lists the active, mature, verified strategies, best first, with their top holding" do
    good = strategy_attributes('GOOD', rmonth: 1.0, rthree_month: 1.0, rsix_month: 1.0, ryear: 1.0, holdings: { 'BTC' => 0.25, 'ETH' => 0.75 })
    poor = strategy_attributes('POOR', rmonth: 0.0, rthree_month: 0.0, rsix_month: 0.0, ryear: 0.0)
    with_iconomi([poor, good, strategy_attributes('UNVERIFIED')], verified: %w[GOOD POOR]) do
      rows = IconomiPages.iconomi

      assert_equal %w[GOOD POOR], rows.pluck('ticker')
      assert_equal({ 'ticker' => 'ETH', 'percent' => '75.0%', 'color' => Asset.find_by_ticker('ETH').css_color }, rows.first['top_holding'])
      cells = rows.first['cells']

      # A cell for each column after the name: the scores, fee weighted then not, each with its rank
      assert_equal 14 - 1, cells.size
      assert_equal [{ 'sort' => 100.0, 'score' => '100.0', 'rank' => '1/2' }] * 2, cells.first(2)
      assert_equal [{ 'value' => 2 }, 'time', { 'value' => 4 }, { 'sort' => 0 }], [cells[2], cells[3].keys.last, cells[4], cells[5]]
      assert_equal '2/2', rows.last['cells'][1]['rank']
    end
  end

  test 'a period a strategy has no return for yet is a blank cell' do
    young = strategy_attributes('YOUNG', rsix_month: nil, ryear: nil)
    with_iconomi([young, strategy_attributes('OLD')]) do
      returns = IconomiPages.iconomi.find { |row| row['ticker'] == 'YOUNG' }['cells'][6, 6]

      assert_equal [{ 'sort' => 0, 'class' => 'bg-white' }] * 2, returns.last(2)
      assert(returns.first(4).all? { |cell| cell['score'] })
    end
  end

  test 'an asset with no colour of its own gets one from its ticker, the same every time' do
    assert_equal Asset.new(ticker: 'XYZ').css_color, Asset.new(ticker: 'XYZ').css_color
    refute_equal Asset.new(ticker: 'XYZ').css_color, Asset.new(ticker: 'ABC').css_color
    assert_equal '#ff0000', Asset.new(ticker: 'XYZ', color: 'ff0000').css_color
  end

  test "the issue lists the strategies and assets with no status, and isn't there when none is left" do
    with_iconomi([strategy_attributes('NEW', holdings: { 'DOGE' => 1.0 }), strategy_attributes('OLD')], verified: %w[OLD]) do
      body = IconomiPages.unreviewed

      assert_includes body, "New strategies, with no status in data/iconomi/strategies.csv:\n\n- NEW strategy (NEW)"
      assert_includes body, "New assets, with no status in data/iconomi/assets.csv:\n\n- DOGE coin (DOGE)"
      refute_includes body, 'OLD'
    end

    with_iconomi([strategy_attributes('OLD')]) { assert_equal '', IconomiPages.unreviewed }
  end

  test "Metastrategy's page is empty until ICONOMI has been fetched" do
    with_fetched { assert_nil IconomiPages.metastrategy }
  end

  # Metastrategy as ICONOMI's structure says it is: holding these { ticker => [its weight, the weight it was rebalanced to] }
  def structure(weights)
    { 'lastRebalanced' => Time.utc(2026, 11, 20, 16).to_i,
      'values' => weights.map { |t, (now, rebalanced)| { 'assetTicker' => t, 'targetWeight' => now, 'rebalancedWeight' => rebalanced } } }
  end

  # Metastrategy among 50 others, all larger, with rising returns, the first 25 of them below its year's
  def metastrategy_page(strategies: many_strategies, weights: { 'BTC' => [0.75, 0.5], 'ETH' => [0.25, 0.5], 'PAXG' => [0.0, 0.0] })
    metastrategy = strategy_attributes(Strategy::METASTRATEGY, aum: 1000, rmonth: 0.25, rthree_month: 0.5, rsix_month: 0.5, ryear: 1.0,
                                                               rweek: nil, holdings: { 'BTC' => 0.5, 'ETH' => 0.3, 'PAXG' => 0.2 })
    with_iconomi(strategies + [metastrategy], metastrategy: structure(weights)) do
      with_env('NUMBER_OF_ASSETS' => '2') { IconomiPages.metastrategy }
    end
  end

  test "Metastrategy's page says how it ranks against the larger strategies, and over each period" do
    # And one smaller, which it does better than too, but isn't counted among those it's chosen over
    page = metastrategy_page(strategies: many_strategies + [strategy_attributes('SMALL', aum: 500, ryear: 0.1)])

    assert_equal [51, 50, 25], page.values_at('acs_index', 'larger_strategies', 'outperforming_count')
    assert_equal Array.new(25) { |i| "S#{i} strategy" }.sort, page['outperforming'].split(/, | and /).sort
    assert_equal '2026-11-20T16:00:00Z', page['last_rebalanced']
    returns = page['returns']

    # No return for the week yet. Over the month it's 26th of 52, S25's 0.25 tying with its own
    assert_nil returns[1]
    assert_equal({ 'score' => '51.0', 'top' => '50%' }, returns[2])
  end

  test "Metastrategy's page shows its weights against those it would rebalance to, and how far each has moved" do
    page = metastrategy_page
    btc, eth, paxg = page['assets']

    assert_equal %w[BTC ETH PAXG], page['assets'].pluck('ticker')
    assert_equal({ 'ticker' => 'BTC', 'name' => 'BTC coin', 'decrease_bar' => nil, 'increase_bar' => '100.0%', 'actual_sort' => 0.75,
                   'actual' => '75.0%', 'diff' => '+2500', 'diff_color' => 'green', 'proposed' => '62.5%' }, btc.except('proposed_sort'))
    assert_in_delta 0.625, btc['proposed_sort'], 0.0002
    assert_equal ['100.0%', nil, '-2500', 'red', '37.5%'], eth.values_at('decrease_bar', 'increase_bar', 'diff', 'diff_color', 'proposed')
    # Not moved, and not among those it would hold
    assert_equal [nil, nil, '0', nil, nil], paxg.values_at('decrease_bar', 'increase_bar', 'diff', 'diff_color', 'proposed')
    assert_equal({ 'labels' => %w[BTC ETH PAXG], 'data' => [0.75, 0.25, 0.0], 'colors' => %w[BTC ETH PAXG].map { |t| Asset.new(ticker: t).css_color } },
                 page['chart'])
    assert_nil page['proposals_error']
  end

  test "Metastrategy's page says why it can't propose weights, and still shows its own" do
    page = metastrategy_page(strategies: many_strategies(10))

    # Not counting Metastrategy itself
    assert_equal '10 active, mature, verified strategies', page['proposals_error']
    assert_equal [nil, nil], page['assets'].pluck('proposed').first(2)
    assert_equal %w[75.0% 25.0%], page['assets'].pluck('actual').first(2)
  end
end
