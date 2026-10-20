# frozen_string_literal: true

# One target weight in the portfolio's aim, such as 40% META.
# This is separate from a holding: the aim can include a stock that is
# not owned yet, and a holding can exist for a stock the aim has dropped.
class Allocation
  attr_reader :stock, :weight

  def initialize(stock:, weight:)
    parsed = BigDecimal(weight.to_s)
    raise ArgumentError, "weight must not be negative" if parsed.negative?

    @stock = stock
    @weight = parsed
  end

  def symbol
    stock.symbol
  end
end
