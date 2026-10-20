# frozen_string_literal: true

# A proposed whole-share buy or sell. The portfolio does not execute it.
class Trade
  attr_reader :stock, :action, :shares

  def initialize(stock:, action:, shares:)
    @stock = stock
    @action = action
    @shares = shares
  end

  def symbol
    stock.symbol
  end
end
