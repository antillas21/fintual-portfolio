# frozen_string_literal: true

# Entry point for an irb session: `require "portfolio_management"`.
# Loads every class the portfolio module needs.
require "bigdecimal"

require_relative "stock"
require_relative "holding"
require_relative "allocation"
require_relative "trade"
require_relative "rebalance_plan"
require_relative "portfolio"
