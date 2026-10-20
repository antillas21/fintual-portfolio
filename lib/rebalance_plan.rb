# frozen_string_literal: true

# The trades that would move a portfolio toward its target, plus the cash
# that whole-share rounding cannot invest.
class RebalancePlan
  attr_reader :sells, :buys, :leftover_cash

  def initialize(sells:, buys:, leftover_cash:)
    @sells = sells
    @buys = buys
    @leftover_cash = leftover_cash
  end
end
