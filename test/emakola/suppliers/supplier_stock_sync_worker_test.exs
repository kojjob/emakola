defmodule Emakola.Suppliers.SupplierStockSyncWorkerTest do
  @moduledoc """
  Task 2 (supplier-stock-truth): `SupplierStockSyncWorker` propagates a
  supplier source variant's live availability (`available and in_stock?`) to
  every ACTIVE reseller listing variant mapped to it — availability only,
  never title/description/price (that stays on `ListingImporter.sync/2`,
  deliberately unwired). Recomputes from CURRENT state so repeated/coalesced
  runs are last-write-wins correct.

  Also covers the enqueue seams wired into `Emakola.Inventory.adjust/5` and
  the Variant `:update` action (`Emakola.Catalog.Changes.EnqueueSupplierStockSync`).
  """

  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Emakola.Factory
  import Ecto.Query

  alias Emakola.Suppliers.{ListingImporter, Network, Offers}
  alias Emakola.Suppliers.Workers.SupplierStockSyncWorker

  setup do
    {wholesaler_actor, wholesaler} = create_merchant_with_store!(%{name: "Sync wholesaler"})
    {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Sync reseller"})

    {:ok, connection} =
      Network.request(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: wholesaler.id
      })

    {:ok, _active} = Network.approve(reseller_actor, connection)

    %{
      wholesaler_actor: wholesaler_actor,
      wholesaler: wholesaler,
      reseller_actor: reseller_actor,
      reseller: reseller
    }
  end

  test "sell-out propagates: zeroing the source stock flips the reseller variant unavailable",
       ctx do
    %{source_variant: source, reseller_variant: reseller_variant} = import_variant!(ctx)
    location = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    assert reload_variant(reseller_variant).available == true

    assert {:ok, :adjusted} = Emakola.Inventory.adjust(source.id, location.id, -8, :adjustment)

    # Seam: Inventory.adjust itself enqueued the sync job.
    assert_enqueued(worker: SupplierStockSyncWorker, args: %{"variant_id" => source.id})

    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    assert reload_variant(reseller_variant).available == false
  end

  test "a completed sync job does not block a fresh enqueue within the debounce window (C1)" do
    variant_id = Ash.UUID.generate()

    assert :ok = SupplierStockSyncWorker.enqueue(variant_id)

    [first_job] =
      all_enqueued(worker: SupplierStockSyncWorker, args: %{"variant_id" => variant_id})

    from(j in Oban.Job, where: j.id == ^first_job.id)
    |> Emakola.Repo.update_all(set: [state: "completed", completed_at: DateTime.utc_now()])

    # Oban's unique default `states` list includes `:completed` — a finished
    # job would otherwise block a new insert for the rest of the 60s period,
    # silently dropping a real stock change that arrives after the previous
    # sync finished. `states: :incomplete` (`[:suspended, :available,
    # :scheduled, :executing, :retryable]`) excludes exactly the terminal
    # states that will never run again (`:completed`, `:discarded`,
    # `:cancelled`), which is what makes this a debounce (coalesce a burst)
    # rather than a once-per-60s suppression. See the next test for
    # `:retryable`'s dedup behavior, which is different from `:completed`'s
    # on purpose.
    assert :ok = SupplierStockSyncWorker.enqueue(variant_id)

    assert [new_job] =
             all_enqueued(worker: SupplierStockSyncWorker, args: %{"variant_id" => variant_id})

    assert new_job.id != first_job.id
  end

  test "a retryable sync job dedups a fresh enqueue instead of spawning a duplicate" do
    variant_id = Ash.UUID.generate()

    assert :ok = SupplierStockSyncWorker.enqueue(variant_id)

    [first_job] =
      all_enqueued(worker: SupplierStockSyncWorker, args: %{"variant_id" => variant_id})

    from(j in Oban.Job, where: j.id == ^first_job.id)
    |> Emakola.Repo.update_all(
      set: [state: "retryable", scheduled_at: DateTime.add(DateTime.utc_now(), 30, :second)]
    )

    # Unlike `:completed`, `:retryable` IS in the `:incomplete` unique group,
    # so this enqueue is coalesced into the existing job rather than
    # spawning a sibling — verified: still exactly one row for this variant,
    # and it's the original, still `:retryable`. This is the correct
    # behavior, not just a tolerated one: the pending job hasn't run yet, so
    # when its backoff elapses it queries CURRENT state at that time —
    # nothing is lost by not spawning a duplicate, and the queue avoids
    # piling up redundant jobs while one is already waiting to retry.
    assert :ok = SupplierStockSyncWorker.enqueue(variant_id)

    all_jobs =
      Emakola.Repo.all(from(j in Oban.Job, where: j.args["variant_id"] == ^variant_id))

    assert [%{id: id, state: "retryable"}] = all_jobs
    assert id == first_job.id
  end

  test "sync-caused-off: a restock re-enables and clears the sync-pause marker", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} = import_variant!(ctx)
    location = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    assert {:ok, :adjusted} = Emakola.Inventory.adjust(source.id, location.id, -8, :adjustment)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    synced_off = reload_variant(reseller_variant)
    assert synced_off.available == false
    # The sync itself turned this off, so the marker is stamped — that's
    # what makes the next restock's re-enable safe (contrast with the
    # manual-off test below, where the marker stays nil and restock must
    # NOT re-enable).
    assert synced_off.supplier_sync_paused_at != nil

    assert {:ok, :adjusted} = Emakola.Inventory.restock(source.id, location.id, 5)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    synced_on = reload_variant(reseller_variant)
    assert synced_on.available == true
    assert synced_on.supplier_sync_paused_at == nil
  end

  test "manual-off sticks: a reseller's deliberate available:false survives a supplier restock",
       ctx do
    %{source_variant: source, reseller_variant: reseller_variant} = import_variant!(ctx)
    location = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    # The reseller turns their own listing off via the manual admin path —
    # `Emakola.Catalog.update_variant/3` (the `:update` action), the same
    # one `save_dropship_variant/3` in the admin inventory LiveView calls.
    assert {:ok, _updated} =
             Emakola.Catalog.update_variant(reseller_variant, %{available: false},
               authorize?: false
             )

    manually_off = reload_variant(reseller_variant)
    assert manually_off.available == false
    assert manually_off.supplier_sync_paused_at == nil

    # The supplier restocks (source stays fully in stock throughout) and the
    # sync runs — since the marker is nil, the sync must NOT re-enable a
    # listing it never turned off itself.
    assert {:ok, :adjusted} = Emakola.Inventory.restock(source.id, location.id, 5)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    still_off = reload_variant(reseller_variant)
    assert still_off.available == false
    assert still_off.supplier_sync_paused_at == nil
  end

  test "manually re-enabling clears the sync-pause marker; a later sell-out re-stamps it", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} = import_variant!(ctx)
    location = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    assert {:ok, :adjusted} = Emakola.Inventory.adjust(source.id, location.id, -8, :adjustment)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    synced_off = reload_variant(reseller_variant)
    assert synced_off.available == false
    assert synced_off.supplier_sync_paused_at != nil

    # The reseller manually re-enables it (e.g. a substitute is on the way)
    # — touching the toggle reclaims ownership, clearing the marker. Must
    # act on the freshly-reloaded (post-sync) record: passing the original,
    # pre-sync struct would still show `available: true` from creation, so
    # Ash would see no real change and skip the write entirely.
    assert {:ok, _updated} =
             Emakola.Catalog.update_variant(synced_off, %{available: true}, authorize?: false)

    manually_on = reload_variant(reseller_variant)
    assert manually_on.available == true
    assert manually_on.supplier_sync_paused_at == nil

    # The supplier restocking now changes nothing — the reseller already
    # turned it on manually, so available already matches target and the
    # marker stays cleared (no spurious re-stamp from a mere restock).
    assert {:ok, :adjusted} = Emakola.Inventory.restock(source.id, location.id, 8)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    still_manually_on = reload_variant(reseller_variant)
    assert still_manually_on.available == true
    assert still_manually_on.supplier_sync_paused_at == nil

    # A LATER, independent sell-out is a fresh sync-caused off — it
    # re-stamps the marker.
    assert {:ok, :adjusted} = Emakola.Inventory.adjust(source.id, location.id, -8, :adjustment)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    re_synced_off = reload_variant(reseller_variant)
    assert re_synced_off.available == false
    assert re_synced_off.supplier_sync_paused_at != nil
  end

  test "a paused listing stays paused even after the source restocks", ctx do
    %{source_variant: source, reseller_variant: reseller_variant, offer: offer} =
      import_variant!(ctx)

    location = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    assert :ok = ListingImporter.pause_offer_listings!(offer.id)
    assert reload_variant(reseller_variant).available == false

    assert {:ok, :adjusted} = Emakola.Inventory.restock(source.id, location.id, 5)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    assert reload_variant(reseller_variant).available == false
  end

  test "supplier setting available: false wins even with stock on hand", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} = import_variant!(ctx)

    assert reload_variant(source).stock_quantity == 8

    assert {:ok, _updated} =
             Emakola.Catalog.update_variant(source, %{available: false}, authorize?: false)

    # Seam: the Variant :update action enqueued the sync job.
    assert_enqueued(worker: SupplierStockSyncWorker, args: %{"variant_id" => source.id})

    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    assert reload_variant(reseller_variant).available == false
  end

  test "no-op for a variant with no offer mapping", ctx do
    product = create_product!(ctx.reseller, status: :active)
    variant = create_variant!(product, ctx.reseller, stock_quantity: 10)

    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => variant.id})

    assert reload_variant(variant).available == true
  end

  test "a price-only update on the source variant does not enqueue", ctx do
    %{source_variant: source} = import_variant!(ctx)

    assert {:ok, _updated} =
             Emakola.Catalog.update_variant(source, %{price: 7_000}, authorize?: false)

    refute_enqueued(worker: SupplierStockSyncWorker)
  end

  test "repeated perform is a no-op once availability already matches", ctx do
    %{source_variant: source, reseller_variant: reseller_variant} = import_variant!(ctx)
    location = Emakola.Inventory.ensure_default_location!(ctx.wholesaler.id)

    assert {:ok, :adjusted} = Emakola.Inventory.adjust(source.id, location.id, -8, :adjustment)
    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    updated_at = reload_variant(reseller_variant).updated_at

    assert :ok = perform_job(SupplierStockSyncWorker, %{"variant_id" => source.id})

    assert reload_variant(reseller_variant).updated_at == updated_at
  end

  # ── Helpers ────────────────────────────────────────────────────

  defp import_variant!(ctx, variant_attrs \\ %{}) do
    product = create_product!(ctx.wholesaler, status: :active, title: "Kente sandals")

    source_variant =
      create_variant!(
        product,
        ctx.wholesaler,
        Map.merge(
          %{
            price: 6_000,
            sku: "SANDAL-#{System.unique_integer([:positive])}",
            stock_quantity: 8,
            track_inventory: true
          },
          Map.new(variant_attrs)
        )
      )

    {:ok, offer} =
      Offers.create_draft(ctx.wholesaler_actor, %{
        wholesaler_store_id: ctx.wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, terms} =
      Offers.add_variant(ctx.wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, offer} = Offers.publish(ctx.wholesaler_actor, offer)

    {:ok, listing} = ListingImporter.import(ctx.reseller_actor, ctx.reseller.id, offer)

    [reseller_variant | _] = listing.reseller_product.variants

    %{
      source_variant: source_variant,
      terms: terms,
      reseller_variant: reseller_variant,
      offer: offer
    }
  end

  defp reload_variant(variant),
    do: Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
end
