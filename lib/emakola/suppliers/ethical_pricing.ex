defmodule Emakola.Suppliers.EthicalPricing do
  @moduledoc "Recommends bounded prices without scarcity surcharges or prices below supplier terms."

  def recommend(variant, signals) do
    supplier = variant.supplier_price
    suggested = variant.suggested_retail_price
    maximum = variant.max_retail_price || suggested
    views = Map.get(signals, :views, 0)
    orders = Map.get(signals, :orders, 0)

    candidate =
      cond do
        views >= 20 and orders == 0 -> div(suggested * 95, 100)
        views >= 50 and orders * 100 < views * 2 -> div(suggested * 97, 100)
        true -> suggested
      end

    price = candidate |> max(supplier) |> min(maximum)

    %{
      price: price,
      supplier_floor: supplier,
      supplier_ceiling: maximum,
      scarcity_surcharge: 0,
      reason: reason(price, suggested, views, orders)
    }
  end

  defp reason(price, suggested, views, 0) when price < suggested and views >= 20,
    do: "High interest has not converted yet, so test a lower price within supplier bounds."

  defp reason(_price, _suggested, _views, _orders),
    do: "Use the supplier's suggested price; demand never triggers a scarcity surcharge."
end
