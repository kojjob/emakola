defmodule Emakola.Suppliers.Workers.SupplierStockSyncWorker do
  @moduledoc """
  Propagates a supplier source variant's live availability
  (`available and in_stock?`) to every ACTIVE reseller listing variant mapped
  to it. Availability only — never title/description/price (that is
  `ListingImporter.sync/2`, deliberately unwired). Recomputes from CURRENT
  state so Oban unique-coalesced bursts are last-write-wins correct.

  Turning a variant OFF is always allowed — the sync must never be blocked
  from reflecting a real sell-out. Turning a variant back ON only happens if
  `supplier_sync_paused_at` shows the sync itself was the one that turned it
  off; a reseller's own deliberate `available: false` (marker left `nil` by
  the general `:update` action) sticks until the reseller re-enables it.
  Writes go through the dedicated `:sync_availability` action, never
  `:update`, so this marker bookkeeping stays correct.
  """
  use Oban.Worker,
    queue: :orders,
    max_attempts: 3,
    unique: [period: 60, fields: [:args], states: :incomplete]

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
      |> Enum.each(&sync_reseller_availability(&1.reseller_variant, target))
    end

    :ok
  end

  defp sync_reseller_availability(variant, target) do
    cond do
      variant.available == target ->
        :ok

      target == false ->
        Emakola.Catalog.sync_availability_variant!(variant, %{available: false},
          authorize?: false
        )

      not is_nil(variant.supplier_sync_paused_at) ->
        Emakola.Catalog.sync_availability_variant!(variant, %{available: true}, authorize?: false)

      true ->
        # target == true but the marker is nil: a reseller manually turned
        # this off, not the sync — leave it alone.
        :ok
    end
  end
end
