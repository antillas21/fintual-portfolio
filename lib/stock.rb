# frozen_string_literal: true

# A stock is an instrument plus the last price the app handed it.
# It does not know how many shares a portfolio owns, and it does not
# fetch a market. Exchanges are closed most hours of the week, so the
# caller decides which print counts as the last available price: the
# last trade while the session is open, or the official close while it is shut.
class Stock
  attr_reader :symbol, :price

  def initialize(symbol)
    @symbol = symbol.to_s.strip.upcase
    raise ArgumentError, "symbol is required" if @symbol.empty?

    @price = nil
  end

  # Receives the last available price from outside the portfolio.
  # A later call replaces the stored price. Nothing here opens a session
  # or talks to an exchange.
  def current_price(last_available_price)
    raw = last_available_price.to_s.strip
    raise ArgumentError, "price is required" if raw.empty?

    parsed = BigDecimal(raw)
    raise ArgumentError, "price must be positive" unless parsed.positive?

    @price = parsed
  end
end
