defmodule Emakola.Inventory do
  @moduledoc """
  The Inventory context — stock-level reads and status classification.

  ## Phase 2a (current): service-module shell

  Today, inventory is a single `stock_quantity` integer + `track_inventory`
  boolean on `Emakola.Catalog.Variant`. This module is the read-side seam
  that future multi-location work will plug into. It exposes:

    * `list_low_stock/2` — variants below threshold for a store
    * `stock_status/1` — classify a variant as `:in_stock | :low | :out`
    * `out_of_stock?/1` — convenience predicate
    * `low_stock_threshold/0` — single source of truth for the threshold

  Writes still flow through `Catalog.Variant`. When we add real
  `stock_levels` (variant_id, location_id, quantity) for multi-location
  support, the writes move here — but reads will keep this same API.

  See `docs/PLAN-domain-restructuring-2026-04-26.md` for the multi-phase
  plan. This is intentionally NOT a `use Ash.Domain` yet — Variant lives
  in `Catalog`, and pointing two Ash domains at the same table tends to
  surface ownership ambiguity. We'll wire Ash when there's a separate
  resource to own.
  """

  require Ash.Query

  @low_stock_threshold 10

  @doc """
  Default low-stock threshold used by the dashboard, alert worker, and
  inventory page. Override per-call by passing a different `threshold`
  to `list_low_stock/2`.
  """
  def low_stock_threshold, do: @low_stock_threshold

  @doc """
  Returns variants in the given store whose stock has fallen below
  `threshold`, ordered by stock ascending. Only includes variants that
  track inventory (`track_inventory == true`).

  Limited to 10 results — this is a "needs attention" widget, not a
  full report.

  Returns `[]` on any read error (rather than raising) since the
  caller is typically the dashboard which renders many widgets in
  parallel and shouldn't crash on one failure.
  """
  @spec list_low_stock(binary(), integer()) :: list(map())
  def list_low_stock(store_id, threshold \\ @low_stock_threshold) do
    case Emakola.Catalog.Variant
         |> Ash.Query.filter(
           store_id == ^store_id and
             stock_quantity < ^threshold and
             track_inventory == true
         )
         |> Ash.Query.sort(stock_quantity: :asc)
         |> Ash.Query.limit(10)
         |> Ash.Query.load(:product)
         |> Ash.read(authorize?: false) do
      {:ok, variants} -> variants
      _ -> []
    end
  end

  @doc """
  Classifies a variant by stock level.

  Returns one of:
    * `:in_stock` — quantity ≥ threshold (default 10)
    * `:low` — quantity 1–9
    * `:out` — quantity 0 (or negative — treated as out)

  Untracked variants (`track_inventory == false`) always return
  `:in_stock` since the merchant has signalled they don't manage
  stock for this variant.

  Dropshipped variants (those linked to a supplier via `supplier_id`)
  don't track numeric stock — availability is driven by the merchant-set
  `available` flag: `:out` when `available == false`, else `:in_stock`.
  """
  @spec stock_status(map()) :: :in_stock | :low | :out
  def stock_status(%{supplier_id: sid, available: true}) when not is_nil(sid), do: :in_stock
  def stock_status(%{supplier_id: sid, available: false}) when not is_nil(sid), do: :out

  def stock_status(%{track_inventory: false}), do: :in_stock
  def stock_status(%{stock_quantity: q}) when q <= 0, do: :out
  def stock_status(%{stock_quantity: q}) when q < @low_stock_threshold, do: :low
  def stock_status(_variant), do: :in_stock

  @doc """
  Convenience predicate. Equivalent to `stock_status(variant) == :out`.
  """
  @spec out_of_stock?(map()) :: boolean()
  def out_of_stock?(variant), do: stock_status(variant) == :out
end
