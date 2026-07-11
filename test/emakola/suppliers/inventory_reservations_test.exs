defmodule Emakola.Suppliers.InventoryReservationsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Ecto.Query
  require Ash.Query

  alias Emakola.Suppliers.{InventoryReservations, ListingImporter, Network, Offers}

  setup do
    {supplier_actor, supplier} = create_merchant_with_store!()
    {reseller_actor, reseller} = create_merchant_with_store!()
    product = create_product!(supplier, status: :active, title: "Reserved Basket")
    variant = create_variant!(product, supplier, stock_quantity: 12, track_inventory: true)

    {:ok, offer} =
      Offers.create_draft(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, terms} =
      Offers.add_variant(supplier_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 6_000
      })

    {:ok, offer} = Offers.publish(supplier_actor, offer)

    {:ok, pending} =
      Network.request(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: supplier.id
      })

    {:ok, _connection} = Network.approve(reseller_actor, pending)

    %{
      supplier_actor: supplier_actor,
      supplier: supplier,
      reseller_actor: reseller_actor,
      reseller: reseller,
      terms: terms,
      offer: offer,
      variant: variant
    }
  end

  test "atomically reserves and releases stock with a transparent eligibility snapshot", ctx do
    {:ok, policy} =
      InventoryReservations.create_policy(
        ctx.supplier_actor,
        ctx.supplier.id,
        ctx.terms.id,
        %{minimum_tier: :starter, max_quantity_per_reseller: 5, reservation_hours: 24}
      )

    assert policy.reason_code == "PASSPORT_TIER_STARTER"

    assert {:ok, reservation} =
             InventoryReservations.reserve(ctx.reseller_actor, ctx.reseller.id, policy.id, 4)

    assert reservation.status == :active
    assert reservation.reason_code == policy.reason_code
    assert reservation.eligibility_snapshot["passport_tier"] == "starter"
    assert reservation.eligibility_snapshot["minimum_tier"] == "starter"
    assert DateTime.compare(reservation.expires_at, reservation.reserved_at) == :gt

    held_variant = Ash.get!(Emakola.Catalog.Variant, ctx.variant.id, authorize?: false)
    assert held_variant.stock_quantity == 8

    assert {:error, :reseller_limit_exceeded} =
             InventoryReservations.reserve(ctx.reseller_actor, ctx.reseller.id, policy.id, 2)

    assert {:ok, released} =
             InventoryReservations.release(
               ctx.reseller_actor,
               ctx.reseller.id,
               reservation.id
             )

    assert released.status == :released
    assert released.released_at

    assert Ash.get!(Emakola.Catalog.Variant, ctx.variant.id, authorize?: false).stock_quantity ==
             12
  end

  test "denies merchants below the published tier and cross-store policy authors", ctx do
    {:ok, policy} =
      InventoryReservations.create_policy(
        ctx.supplier_actor,
        ctx.supplier.id,
        ctx.terms.id,
        %{minimum_tier: :reliable, max_quantity_per_reseller: 3, reservation_hours: 12}
      )

    assert {:error, :not_eligible} =
             InventoryReservations.reserve(ctx.reseller_actor, ctx.reseller.id, policy.id, 1)

    {stranger, stranger_store} = create_merchant_with_store!()

    assert {:error, :forbidden} =
             InventoryReservations.create_policy(
               stranger,
               stranger_store.id,
               ctx.terms.id,
               %{minimum_tier: :starter, max_quantity_per_reseller: 1, reservation_hours: 1}
             )
  end

  test "expiry worker restores only the unused held quantity once", ctx do
    {:ok, policy} =
      InventoryReservations.create_policy(
        ctx.supplier_actor,
        ctx.supplier.id,
        ctx.terms.id,
        %{minimum_tier: :starter, max_quantity_per_reseller: 5, reservation_hours: 1}
      )

    {:ok, reservation} =
      InventoryReservations.reserve(ctx.reseller_actor, ctx.reseller.id, policy.id, 3)

    past = DateTime.add(DateTime.utc_now(), -60, :second)

    Emakola.Repo.update_all(
      from(r in "earn_inventory_reservations", where: r.id == type(^reservation.id, Ecto.UUID)),
      set: [expires_at: past]
    )

    assert :ok =
             Emakola.Suppliers.Workers.InventoryReservationExpiryWorker.perform(%Oban.Job{})

    expired = Ash.get!(Emakola.Suppliers.InventoryReservation, reservation.id, authorize?: false)
    assert expired.status == :expired

    assert Ash.get!(Emakola.Catalog.Variant, ctx.variant.id, authorize?: false).stock_quantity ==
             12

    assert :ok = InventoryReservations.expire_due()

    assert Ash.get!(Emakola.Catalog.Variant, ctx.variant.id, authorize?: false).stock_quantity ==
             12
  end

  test "paid order consumption is idempotent and expiry restores only unused units", ctx do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: ctx.supplier.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: "ACCT_reserved_supplier"})
    |> Ash.update!(authorize?: false)

    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: ctx.reseller.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: "ACCT_reserved"})
    |> Ash.update!(authorize?: false)

    {:ok, listing} = ListingImporter.import(ctx.reseller_actor, ctx.reseller.id, ctx.offer)
    mapping = List.first(listing.listing_variants)

    {:ok, policy} =
      InventoryReservations.create_policy(
        ctx.supplier_actor,
        ctx.supplier.id,
        ctx.terms.id,
        %{minimum_tier: :starter, max_quantity_per_reseller: 5, reservation_hours: 24}
      )

    {:ok, reservation} =
      InventoryReservations.reserve(ctx.reseller_actor, ctx.reseller.id, policy.id, 5)

    {:ok, order} =
      Emakola.Orders.CheckoutService.checkout!(
        ctx.reseller.id,
        [%{variant_id: mapping.reseller_variant_id, quantity: 2}],
        []
      )

    assert :ok = InventoryReservations.consume_for_order(order.id, ctx.reseller.id)
    assert :ok = InventoryReservations.consume_for_order(order.id, ctx.reseller.id)

    consumed =
      Ash.get!(Emakola.Suppliers.InventoryReservation, reservation.id, authorize?: false)

    assert consumed.consumed_quantity == 2
    assert consumed.status == :active

    consumptions =
      Emakola.Suppliers.InventoryReservationConsumption
      |> Ash.Query.filter(reservation_id == ^reservation.id)
      |> Ash.read!(authorize?: false)

    assert length(consumptions) == 1
    assert List.first(consumptions).quantity == 2

    assert Ash.get!(Emakola.Catalog.Variant, ctx.variant.id, authorize?: false).stock_quantity ==
             7

    assert {:ok, expired} =
             InventoryReservations.release(
               ctx.supplier_actor,
               ctx.supplier.id,
               reservation.id
             )

    assert expired.status == :released

    assert Ash.get!(Emakola.Catalog.Variant, ctx.variant.id, authorize?: false).stock_quantity ==
             10
  end
end
