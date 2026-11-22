# What the /iconomi and /metastrategy pages show, worked out from the fetched strategies, for their Liquid templates
module IconomiPages
  extend ActiveSupport::NumberHelper

  class << self
    # The strategy evaluator's table: the active, mature, verified strategies, best first, each with its cells after
    # its name, in the table's order: a score and rank, a time, a value, or blank
    def iconomi
      strategies = Strategy.active_mature.select(&:nscore_score).sort_by { |s| -s.score_fee_weighted }
      strategies.map do |strategy|
        asset, weight = strategy.top_holding
        score = ->(x) { score_cell(strategy, x, strategies.count) }
        {
          'ticker' => strategy.ticker,
          'name' => strategy.name,
          'top_holding' => ({ 'ticker' => asset.ticker, 'percent' => "#{(weight * 100).round(2)}%", 'color' => asset.css_color } if asset),
          'cells' => [
            score.call('score_fee_weighted'), score.call('score'),
            { 'value' => strategy.numberOfAssets }, time_cell(strategy.lastRebalanced),
            { 'value' => strategy.monthlyRebalancedCount }, time_cell(strategy.last_posted_at),
            *Strategy::PERIODS.map { |t| strategy.public_send("r#{t}") ? score.call("r#{t}") : { 'sort' => 0, 'class' => 'bg-white' } },
            score.call('aum')
          ]
        }
      end
    end

    # Metastrategy: how it ranks, its current weights and those it would rebalance to. nil before
    # ICONOMI's been fetched
    def metastrategy
      live = Fetched.read(:iconomi, {})['metastrategy']
      strategy = Strategy.find_by_ticker(Strategy::METASTRATEGY)
      return unless live && strategy

      strategies = Strategy.verified
      acs_index = strategy.nscore_index('aum', strategies: strategies)[1]
      outperforming = strategies.select { |s| s.aum && strategy.aum && s.aum > strategy.aum }.sort_by { |s| -s.aum }
                                .select { |s| (s.ryear || 0) < strategy.ryear.to_f }
      {
        'acs_index' => acs_index,
        'larger_strategies' => acs_index - 1,
        'outperforming_count' => outperforming.count,
        'outperforming' => outperforming.map(&:name).to_sentence(last_word_connector: ' and '),
        'last_rebalanced' => Time.at(live['lastRebalanced']).utc.iso8601,
        'returns' => Strategy::PERIODS.map do |t|
          next unless strategy.public_send("r#{t}")

          nscore, index = strategy.nscore_index("r#{t}", strategies: strategies)
          { 'score' => number_to_rounded(nscore, precision: 1), 'top' => number_to_percentage(100 * index / strategies.count, precision: 0) }
        end
      }.merge(weights(live))
    end

    # Its current weights against those it would rebalance to, for the table and the chart
    def weights(live)
      proposed, without_multipliers = proposals
      actual = live['values'].to_h { |h| [h['assetTicker'], h['targetWeight']] }
      rebalanced = live['values'].to_h { |h| [h['assetTicker'], h['rebalancedWeight']] }
      diff = actual.to_h { |k, _v| [k, actual[k] - rebalanced[k]] }
      max_diff = diff.values.map(&:abs).max
      tickers = proposed.keys + without_multipliers.keys + actual.keys + Asset.all.values.select(&:multiplier).sort_by { |a| -a.multiplier }.map(&:ticker)

      {
        'proposals_error' => proposals_error,
        'assets' => tickers.uniq.map do |k|
          asset = Asset.find_by_ticker(k)
          d = diff[k]
          {
            'ticker' => k,
            'name' => asset.name,
            'decrease_bar' => ("#{100 * -d / max_diff}%" if d&.negative?),
            'increase_bar' => ("#{100 * d / max_diff}%" if d&.positive?),
            'actual_sort' => actual[k] || 0,
            'actual' => (number_to_percentage(actual[k] * 100, precision: 1) if actual[k]),
            'diff' => ("#{'+' if d.positive?}#{(d * 10_000).round}" if d),
            'diff_color' => ({ 1 => 'green', -1 => 'red' }[d <=> 0] if d),
            'proposed_sort' => proposed[k] || 0,
            'proposed' => (number_to_percentage(proposed[k] * 100, precision: 1) if proposed[k])
          }
        end,
        'chart' => { 'labels' => actual.keys, 'data' => actual.values, 'colors' => actual.keys.map { |k| Asset.find_by_ticker(k).css_color } }
      }
    end

    # The weights it would rebalance to, with multipliers and without; empty if they can't be worked out
    def proposals
      @proposals ||= Strategy.propose
    rescue KeyError, Strategy::NotEnoughStrategies => e
      @proposals_error = e.message
      [{}, {}]
    end

    def proposals_error
      proposals
      @proposals_error
    end

    def reset!
      @proposals = @proposals_error = nil
      Strategy.reset!
    end

    # The body of the GitHub issue `iconomi-fetch.yml` opens for the strategies and assets with no status yet (not those
    # excluded): blank when there are none
    def unreviewed
      items = { 'strategies' => Strategy.all.reject(&:status),
                'assets' => Asset.all.values.reject(&:status) }.reject { |_, list| list.empty? }
      return '' if items.empty?

      lines = items.flat_map do |kind, list|
        ["New #{kind}, with no status in data/iconomi/#{kind}.csv:", '', *list.map { |i| "- #{i.name} (#{i.ticker})" }, '']
      end
      lines << 'Give each a status there (`verified` or `excluded`), or run Verify the new ICONOMI strategies and assets to verify them all. This ' \
               'issue closes itself once none is left.'
      lines.join("\n")
    end

    private

    def score_cell(strategy, x, count)
      nscore = strategy.public_send("nscore_#{x}")
      { 'sort' => nscore, 'score' => number_to_rounded(nscore, precision: 1), 'rank' => "#{strategy.public_send("index_#{x}")}/#{count}" }
    end

    def time_cell(time)
      time ? { 'sort' => time.to_i, 'time' => time.utc.iso8601 } : { 'sort' => 0 }
    end
  end
end
