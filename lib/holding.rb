# frozen_string_literal: true

# Shares currently owned of one stock. Quantity lives here, not on Stock,
# because how many shares you hold is a fact about the portfolio, not
# about the instrument.
class Holding
  attr_reader :stock, :shares

  def initialize(stock:, shares:)
    raise ArgumentError, "shares must be a whole number" unless shares.is_a?(Integer)
    raise ArgumentError, "shares must not be negative" if shares.negative?

    @stock = stock
    @shares = shares
  end

  def symbol
    stock.symbol
  end
end
