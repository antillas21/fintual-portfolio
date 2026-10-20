# frozen_string_literal: true
require "bigdecimal"

# A portfolio is the shares you hold, the mix you are aiming for, and
# any cash that is not invested. Target weights are fractions of the
# whole account (holdings plus cash) and must sum to 100%. Cash is not
# a stock; leftover cash appears only because whole-share trades cannot
# land on the target exactly.
class Portfolio
  WEIGHT_TOLERANCE = BigDecimal("0.0001")

  attr_reader :cash

  def initialize(holdings:, allocations:, cash: 0)
    @holdings = index_holdings(holdings)
    @allocations = index_allocations(allocations)
    @cash = parse_cash(cash)
    validate_prices_agree
    validate_weight_sum
  end

  def total_value
    cash + market_value
  end

  # Current weight of a symbol against the full account value.
  # An unknown symbol, or an empty account, weighs nothing.
  def current_weight(symbol)
    total = total_value
    return BigDecimal("0") if total.zero?

    value_of(symbol) / total
  end

  # Proposes whole-share trades that move the account toward its target
  # weights. The portfolio itself is left unchanged.
  #
  # Sells run first so their proceeds can fund buys. A holding that is not
  # in the allocation has a target of zero and is sold in full. Share counts
  # are floored: an extra share is never sold just to free cash, and a
  # partial share is never bought. When cash cannot cover every buy, the
  # largest dollar deficit is filled first (symbol order breaks ties).
  #
  # This is a greedy pass, not an optimizer. One expensive share can leave
  # the account slightly off target, with the remainder sitting in cash.
  def rebalance
    total = total_value
    cash_available = cash

    sells = sell_orders(total)
    sells.each { |trade| cash_available += trade.shares * trade.stock.price }

    buys = buy_orders(total, cash_available)
    buys.each { |trade| cash_available -= trade.shares * trade.stock.price }

    RebalancePlan.new(sells: sells, buys: buys, leftover_cash: cash_available)
  end

  private

  BuyCandidate = Struct.new(:symbol, :stock, :deficit, :desired, :price, keyword_init: true)

  def sell_orders(total)
    symbols_in_play.filter_map do |symbol|
      shares = shares_to_sell(symbol, total)
      next if shares.zero?

      Trade.new(stock: stock_for(symbol), action: :sell, shares: shares)
    end
  end

  def buy_orders(total, cash_available)
    remaining = cash_available
    buy_candidates(total).filter_map do |candidate|
      affordable = (remaining / candidate.price).floor
      shares = [candidate.desired, affordable].min
      next if shares.zero?

      remaining -= shares * candidate.price
      Trade.new(stock: candidate.stock, action: :buy, shares: shares)
    end
  end

  def shares_to_sell(symbol, total)
    owned = shares_of(symbol)
    return 0 if owned.zero?

    excess = value_of(symbol) - target_value(symbol, total)
    return 0 unless excess.positive?

    [owned, (excess / price_of(symbol)).floor].min
  end

  def buy_candidates(total)
    symbols_in_play.filter_map do |symbol|
      deficit = target_value(symbol, total) - value_of(symbol)
      next unless deficit.positive?

      price = price_of(symbol)
      desired = (deficit / price).floor
      next if desired.zero?

      BuyCandidate.new(symbol: symbol, stock: stock_for(symbol), deficit: deficit, desired: desired, price: price)
    end.sort_by { |candidate| [-candidate.deficit, candidate.symbol] }
  end

  def symbols_in_play
    (@holdings.keys | @allocations.keys).sort
  end

  def shares_of(symbol)
    @holdings[symbol]&.shares || 0
  end

  def price_of(symbol)
    stock_for(symbol).price
  end

  def stock_for(symbol)
    @holdings[symbol]&.stock || @allocations.fetch(symbol).stock
  end

  def target_value(symbol, total)
    weight = @allocations[symbol]&.weight || BigDecimal("0")
    total * weight
  end

  def index_holdings(holdings)
    holdings.each_with_object({}) do |holding, indexed|
      raise ArgumentError, "duplicate holding for #{holding.symbol}" if indexed.key?(holding.symbol)

      require_price(holding.stock)
      indexed[holding.symbol] = holding
    end
  end

  def index_allocations(allocations)
    allocations.each_with_object({}) do |allocation, indexed|
      raise ArgumentError, "duplicate allocation for #{allocation.symbol}" if indexed.key?(allocation.symbol)

      require_price(allocation.stock)
      indexed[allocation.symbol] = allocation
    end
  end

  def parse_cash(cash)
    raw = cash.to_s.strip
    raise ArgumentError, "cash is required" if raw.empty?

    parsed = BigDecimal(raw)
    raise ArgumentError, "cash must not be negative" if parsed.negative?

    parsed
  end

  def require_price(stock)
    raise ArgumentError, "price is required for #{stock.symbol}" if stock.price.nil? || !stock.price.positive?
  end

  def validate_prices_agree
    @allocations.each do |symbol, allocation|
      holding = @holdings[symbol]
      next unless holding
      next if holding.stock.price == allocation.stock.price

      raise ArgumentError, "conflicting prices for #{symbol}"
    end
  end

  def validate_weight_sum
    sum = @allocations.values.sum(BigDecimal("0"), &:weight)
    return if (sum - 1).abs <= WEIGHT_TOLERANCE

    raise ArgumentError, "weights must sum to 100 percent"
  end

  def market_value
    @holdings.values.sum(BigDecimal("0")) do |holding|
      holding.shares * holding.stock.price
    end
  end

  def value_of(symbol)
    key = symbol.to_s.strip.upcase
    holding = @holdings[key]
    return BigDecimal("0") unless holding

    holding.shares * holding.stock.price
  end
end
