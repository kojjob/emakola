defmodule Emakola.Suppliers.Workers.SupplierStockSyncWorker do
  @moduledoc """
  Propagates a supplier source variant's live availability
  (`available and in_stock?`) to every ACTIVE reseller listing variant mapped
  to it. Availability only — never title/description/price (that is
  `ListingImporter.sync/2`, deliberately unwired). Recomputes from CURRENT
  state so Oban unique-coalesced bursts are last-write-wins correct.
  """
  use Oban.Worker, queue: :orders, max_attempts: 3, unique: [period: 60, fields: [:args]]

  require Ash.Query
  require Logger

  def enqueue(variant_id) do
    %{"variant_id" => variant_id}
    |> new()
    |> Oban.insert()

    :ok
  rescue
    exception ->
      Logger.error("[SupplierStockSync] enqueue failed: " <> Exception.message(exception))
      :ok
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"variant_id" => variant_id}}) do
    offer_variant_ids =
      Emakola.Suppliers.SupplierOfferVariant
      |> Ash.Query.filter(source_variant_id == ^variant_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.id)

    if offer_variant_ids != [] do
      source = Ash.get!(Emakola.Catalog.Variant, variant_id, authorize?: false)
      target = source.available and Emakola.Catalog.Variant.in_stock?(source)

      Emakola.Suppliers.ResellerListingVariant
      |> Ash.Query.filter(offer_variant_id in ^offer_variant_ids)
      |> Ash.Query.load([:reseller_variant, :listing])
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.listing.status == :active))
      |> Enum.each(fn mapping ->
        if mapping.reseller_variant.available != target do
          Emakola.Catalog.update_variant!(mapping.reseller_variant, %{available: target},
            authorize?: false
          )
        end
      end)
    end

    :ok
  end
end
