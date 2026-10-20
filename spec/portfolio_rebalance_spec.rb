require "spec_helper"

RSpec.describe Portfolio do
  def stock(symbol, price)
    stock = Stock.new(symbol)
    stock.current_price(price)
    stock
  end

  describe "valuation" do
    let(:meta) { stock("META", "100") }
    let(:aapl) { stock("AAPL", "50") }

    let(:portfolio) do
      described_class.new(
        holdings: [
          Holding.new(stock: meta, shares: 4),
          Holding.new(stock: aapl, shares: 12)
        ],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ],
        cash: "100"
      )
    end

    it "values holdings plus cash" do
      # 4 * 100 + 12 * 50 + 100 = 1100
      expect(portfolio.total_value).to eq(BigDecimal("1100"))
    end

    it "reports current weights against the full portfolio value" do
      expect(portfolio.current_weight("META")).to eq(BigDecimal("400") / BigDecimal("1100"))
      expect(portfolio.current_weight("aapl")).to eq(BigDecimal("600") / BigDecimal("1100"))
    end

    it "treats an allocated stock with no holding as zero shares" do
      cash_only = described_class.new(
        holdings: [],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ],
        cash: "250"
      )

      expect(cash_only.total_value).to eq(BigDecimal("250"))
      expect(cash_only.current_weight("META")).to eq(BigDecimal("0"))
    end

    it "rejects a holding whose price was never set" do
      unpriced = Stock.new("META")

      expect do
        described_class.new(
          holdings: [Holding.new(stock: unpriced, shares: 1)],
          allocations: [Allocation.new(stock: unpriced, weight: "1")],
          cash: "0"
        )
      end.to raise_error(ArgumentError, /price/i)
    end

    it "rejects negative cash" do
      expect do
        described_class.new(
          holdings: [],
          allocations: [Allocation.new(stock: meta, weight: "1")],
          cash: "-5"
        )
      end.to raise_error(ArgumentError, /cash/i)
    end

    it "rejects duplicate holdings" do
      second_meta = stock("META", "100")

      expect do
        described_class.new(
          holdings: [
            Holding.new(stock: meta, shares: 1),
            Holding.new(stock: second_meta, shares: 1)
          ],
          allocations: [Allocation.new(stock: meta, weight: "1")],
          cash: "0"
        )
      end.to raise_error(ArgumentError, /duplicate/i)
    end

    it "rejects duplicate allocations" do
      expect do
        described_class.new(
          holdings: [],
          allocations: [
            Allocation.new(stock: meta, weight: "0.40"),
            Allocation.new(stock: meta, weight: "0.60")
          ],
          cash: "0"
        )
      end.to raise_error(ArgumentError, /duplicate/i)
    end

    it "rejects weights that do not sum to 100 percent" do
      expect do
        described_class.new(
          holdings: [],
          allocations: [
            Allocation.new(stock: meta, weight: "0.40"),
            Allocation.new(stock: aapl, weight: "0.40")
          ],
          cash: "0"
        )
      end.to raise_error(ArgumentError, /weight/i)
    end
  end

  describe "#rebalance" do
    def orders(trades)
      trades.map { |trade| [trade.symbol, trade.action, trade.shares] }
    end

    def portfolio_for(holdings:, allocations:, cash: "0")
      described_class.new(holdings: holdings, allocations: allocations, cash: cash)
    end

    it "sells the overweight name and buys the underweight name in whole shares" do
      meta = stock("META", "100")
      aapl = stock("AAPL", "50")
      portfolio = portfolio_for(
        holdings: [Holding.new(stock: meta, shares: 10)],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ]
      )

      plan = portfolio.rebalance

      expect(orders(plan.sells)).to eq([["META", :sell, 6]])
      expect(orders(plan.buys)).to eq([["AAPL", :buy, 12]])
      expect(plan.leftover_cash).to eq(BigDecimal("0"))
      expect(portfolio.total_value).to eq(BigDecimal("1000"))
      expect(portfolio.current_weight("META")).to eq(BigDecimal("1"))
    end

    it "proposes no trades when whole shares already match the target" do
      meta = stock("META", "100")
      aapl = stock("AAPL", "50")
      portfolio = portfolio_for(
        holdings: [
          Holding.new(stock: meta, shares: 4),
          Holding.new(stock: aapl, shares: 12)
        ],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ]
      )

      plan = portfolio.rebalance

      expect(plan.sells).to be_empty
      expect(plan.buys).to be_empty
      expect(plan.leftover_cash).to eq(BigDecimal("0"))
    end

    it "sells every share of a stock that is no longer in the target" do
      meta = stock("META", "100")
      goog = stock("GOOG", "20")
      portfolio = portfolio_for(
        holdings: [
          Holding.new(stock: meta, shares: 4),
          Holding.new(stock: goog, shares: 5)
        ],
        allocations: [Allocation.new(stock: meta, weight: "1")]
      )

      plan = portfolio.rebalance

      expect(orders(plan.sells)).to eq([["GOOG", :sell, 5]])
      expect(orders(plan.buys)).to eq([["META", :buy, 1]])
      expect(plan.leftover_cash).to eq(BigDecimal("0"))
    end

    it "leaves leftover cash when a share does not divide the gap" do
      meta = stock("META", "100")
      aapl = stock("AAPL", "70")
      portfolio = portfolio_for(
        holdings: [Holding.new(stock: meta, shares: 3)],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ]
      )

      plan = portfolio.rebalance

      expect(orders(plan.sells)).to eq([["META", :sell, 1]])
      expect(orders(plan.buys)).to eq([["AAPL", :buy, 1]])
      expect(plan.leftover_cash).to eq(BigDecimal("30"))
    end

    it "fills the largest dollar deficit first when cash cannot fund every buy" do
      meta = stock("META", "100")
      aapl = stock("AAPL", "80")
      msft = stock("MSFT", "50")
      portfolio = portfolio_for(
        holdings: [Holding.new(stock: meta, shares: 3)],
        allocations: [
          Allocation.new(stock: meta, weight: "0.50"),
          Allocation.new(stock: aapl, weight: "0.30"),
          Allocation.new(stock: msft, weight: "0.20")
        ]
      )

      plan = portfolio.rebalance

      expect(orders(plan.sells)).to eq([["META", :sell, 1]])
      expect(orders(plan.buys)).to eq([["AAPL", :buy, 1]])
      expect(plan.leftover_cash).to eq(BigDecimal("20"))
    end

    it "returns the same plan on a second call" do
      meta = stock("META", "100")
      aapl = stock("AAPL", "50")
      portfolio = portfolio_for(
        holdings: [Holding.new(stock: meta, shares: 10)],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ]
      )

      first = portfolio.rebalance
      second = portfolio.rebalance

      expect(orders(second.sells)).to eq(orders(first.sells))
      expect(orders(second.buys)).to eq(orders(first.buys))
      expect(second.leftover_cash).to eq(first.leftover_cash)
    end

    it "returns an empty plan when the account is worth nothing" do
      meta = stock("META", "100")
      aapl = stock("AAPL", "50")
      portfolio = portfolio_for(
        holdings: [],
        allocations: [
          Allocation.new(stock: meta, weight: "0.40"),
          Allocation.new(stock: aapl, weight: "0.60")
        ]
      )

      plan = portfolio.rebalance

      expect(plan.sells).to be_empty
      expect(plan.buys).to be_empty
      expect(plan.leftover_cash).to eq(BigDecimal("0"))
    end
  end
end

RSpec.describe Holding do
  it "rejects a negative share count" do
    meta = Stock.new("META")
    meta.current_price("100")

    expect { described_class.new(stock: meta, shares: -1) }.to raise_error(ArgumentError, /shares/i)
  end

  it "rejects a fractional share count" do
    meta = Stock.new("META")
    meta.current_price("100")

    expect { described_class.new(stock: meta, shares: 1.5) }.to raise_error(ArgumentError, /whole/i)
  end
end

RSpec.describe Allocation do
  it "rejects a negative weight" do
    meta = Stock.new("META")
    meta.current_price("100")

    expect { described_class.new(stock: meta, weight: "-0.1") }.to raise_error(ArgumentError, /weight/i)
  end
end
