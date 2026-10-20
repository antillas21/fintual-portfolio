# Portfolio rebalance

A small portfolio module for a personal investing app. It tracks the stocks you hold, the mix you are aiming for, and the whole-share trades that would move you toward that mix.

No database. Prices are pushed in by the caller. `Portfolio#rebalance` returns a plan and does not change the portfolio.

## Assumptions

- A **stock** is a symbol plus the last price the app handed it. Share count is not part of the stock. The stock does not fetch a market. Exchanges are closed most hours of the week, so "last available price" might be the latest trade or the official close. That choice belongs to the caller.
- A **holding** is a stock plus the whole shares currently owned.
- An **allocation** is a stock plus a target weight, such as 40% META and 60% AAPL. A name can be allocated before you own any shares.
- **Cash** is uninvested money. It is not a stock. Target weights are fractions of the whole account (holdings plus cash) and must sum to 100%, within 0.0001.
- A holding that is missing from the allocation has a target weight of zero, so rebalance sells all of its shares.
- Trades are whole shares. Prices use `BigDecimal` so the math is not binary floating point.
- There are no fees, taxes, lot sizes other than one share, or a drift band. Any whole-share gap produces a trade.
- Rebalance is a greedy pass, not an optimizer. It will not sell an extra share just to fund a buy. When one share is expensive relative to the account, the portfolio can stay slightly off target and the unused money stays in cash.

## Algorithm

1. Reject a missing or non-positive price, a negative share count, fractional shares, negative cash, a duplicate symbol, or weights that do not sum to 100%.
2. Value the account: `cash + Σ(shares × price)`. An allocated name with no holding counts as zero shares.
3. For each symbol, `target value = total × weight`.
4. **Sell first.** If the position is above its target, sell `min(shares owned, floor(excess / price))` shares. Add the proceeds to cash.
5. **Buy second**, only with cash on hand. Desired shares are `floor(deficit / price)`. If cash cannot fund every buy, fill the largest dollar deficit first. Ties break by symbol. Never buy a partial share and never spend more cash than is available.
6. Return the sells, the buys, and the leftover cash.

Calling `rebalance` again on an unchanged portfolio returns the same plan.

Worked example: 10 META at 100, no AAPL at 50, no cash, targets 40% / 60%. The account is worth 1000. Sell 6 META for 600. Buy 12 AAPL for 600. Leftover cash is 0.

## Layout

```
lib/stock.rb              symbol and last price
lib/holding.rb            shares owned
lib/allocation.rb         target weight
lib/trade.rb              one proposed buy or sell
lib/rebalance_plan.rb     sells, buys, leftover cash
lib/portfolio.rb          valuation and rebalance
spec/                     examples that lock the rules above
```

## Run the specs

```
bundle install
bundle exec rspec
```

## LLM use

The design and implementation of this sample were done in a Cursor conversation with Grok. Share that conversation with the application, as requested.
