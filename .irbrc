# Started from this directory, `irb` can then `require "portfolio_management"`
# and pick up Stock, Holding, Allocation, Trade, RebalancePlan, and Portfolio.
lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
