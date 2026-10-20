require "spec_helper"

# A stock does not look up a market. The app pushes in the last price that
# was available, which may be the official close when the exchange is shut.
RSpec.describe Stock do
  subject(:stock) { described_class.new("meta") }

  describe "#current_price" do
    it "stores the last available price as a BigDecimal" do
      stock.current_price("188.50")

      expect(stock.price).to eq(BigDecimal("188.50"))
    end

    it "normalizes the symbol" do
      expect(stock.symbol).to eq("META")
    end

    it "rejects a blank price" do
      expect { stock.current_price(nil) }.to raise_error(ArgumentError, /price/i)
      expect { stock.current_price("  ") }.to raise_error(ArgumentError, /price/i)
    end

    it "rejects a zero price" do
      expect { stock.current_price("0") }.to raise_error(ArgumentError, /positive/i)
    end

    it "rejects a negative price" do
      expect { stock.current_price("-1.25") }.to raise_error(ArgumentError, /positive/i)
    end
  end
end
