defmodule EmakolaWeb.Live.Admin.SupplyStockStatus do
  @moduledoc """
  Offer-level supplier stock status for reseller-facing badges: statuses of
  the offer's SOURCE variants, aggregated. Status only — callers must never
  render the supplier's raw quantities.
  """

  def aggregate([]), do: :out

  def aggregate(source_variants) do
    statuses = Enum.map(source_variants, &Emakola.Inventory.stock_status/1)

    cond do
      Enum.all?(statuses, &(&1 == :out)) -> :out
      Enum.any?(statuses, &(&1 == :low)) -> :low
      true -> :in_stock
    end
  end
end
