defmodule Emakola.Suppliers.EthicalPricingTest do
  use ExUnit.Case, async: true

  alias Emakola.Suppliers.EthicalPricing

  test "lowers a poorly converting price within bounds and never adds scarcity pricing" do
    variant = %{supplier_price: 8_000, suggested_retail_price: 10_000, max_retail_price: 12_000}
    recommendation = EthicalPricing.recommend(variant, %{views: 30, orders: 0})

    assert recommendation.price == 9_500
    assert recommendation.price >= recommendation.supplier_floor
    assert recommendation.price <= recommendation.supplier_ceiling
    assert recommendation.scarcity_surcharge == 0
    assert recommendation.reason =~ "lower price"
  end

  test "strong demand never raises the supplier suggested price" do
    variant = %{supplier_price: 8_000, suggested_retail_price: 10_000, max_retail_price: 12_000}
    recommendation = EthicalPricing.recommend(variant, %{views: 1_000, orders: 300})
    assert recommendation.price == 10_000
    assert recommendation.scarcity_surcharge == 0
  end
end
