The 'meta' in this strategy is that it scores *every coin* on ICONOMI according its weight across *all strategies* on the ICONOMI platform, further weighting by the performance of each strategy. It then takes the top 10 coins by score, and weights them according to their relative scores, with daily rebalancing.

**Thus on any given day Metastrategy is a mix of the current top performing strategies.**

In pseudocode:

```
for each strategy
  for each coin in each strategy
    score_of_coin_i += coin_weight_in_strategy * performance_score_of_strategy
  end
end

sort coins by score
take top 10 coins by score
weight coins according to relative scores
```

For example, say there are two strategies, `A` and `B`.

`A` has coins <code>x<sub>1</sub></code>, <code>x<sub>2</sub></code>, <code>x<sub>3</sub></code>.

`B` has coins <code>x<sub>2</sub></code>, <code>x<sub>3</sub></code>, <code>x<sub>4</sub></code>.

The weight of coin <code>x<sub>i</sub></code> in strategy `Y` is <code>w<sup>Y</sup>(x<sub>i</sub>)</code>.

The performance score of strategy `Y` is <code>p<sup>Y</sup></code>.

Then the score of the coins <code>x<sub>1</sub>&hellip;x<sub>4</sub></code> is:

<code>S(x<sub>1</sub>) = w<sup>A</sup>(x<sub>1</sub>).p<sup>A</sup></code>

<code>S(x<sub>2</sub>) = w<sup>A</sup>(x<sub>2</sub>).p<sup>A</sup> + w<sup>B</sup>(x<sub>2</sub>).p<sup>B</sup></code>

<code>S(x<sub>3</sub>) = w<sup>A</sup>(x<sub>3</sub>).p<sup>A</sup> + w<sup>B</sup>(x<sub>3</sub>).p<sup>B</sup></code>

<code>S(x<sub>4</sub>) = w<sup>B</sup>(x<sub>4</sub>).p<sup>B</sup></code>

The performance score of a strategy  <code>p<sup>Y</sup></code> is calculated as

```
performance_score = (4 * 1_month_performance) + (3 * three_month_performance) + (2 * six_month_performance) + (1 * year_performance)
```

[View the full code](https://github.com/stephenreid321/stephenreid/blob/master/models/strategy.rb) (see the `self.proposed` method)