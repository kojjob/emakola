defmodule Emakola.Suppliers.GroupBuysTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Ecto.Query

  alias Emakola.Suppliers.{GroupBuys, ListingImporter, Network, Offers}
  alias Emakola.Suppliers.Workers.GroupBuyExpiryWorker

  setup do
    {supplier_actor, supplier} = create_merchant_with_store!()
    {reseller_actor, reseller} = create_merchant_with_store!()
    product = create_product!(supplier, status: :active, title: "Group Bag")
    variant = create_variant!(product, supplier, stock_quantity: 20)

    {:ok, offer} =
      Offers.create_draft(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        source_product_id: product.id,
        earning_model: :markup
      })

    {:ok, _terms} =
      Offers.add_variant(supplier_actor, offer, %{
        source_variant_id: variant.id,
        supplier_price: 5_000,
        suggested_retail_price: 6_500,
        max_retail_price: 7_000
      })

    {:ok, offer} = Offers.publish(supplier_actor, offer)

    {:ok, pending} =
      Network.request(supplier_actor, %{
        wholesaler_store_id: supplier.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: supplier.id
      })

    {:ok, _active} = Network.approve(reseller_actor, pending)
    {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, offer)
    listing = Ash.load!(listing, [listing_variants: :offer_variant], authorize?: false)

    %{
      actor: reseller_actor,
      store: reseller,
      listing: listing,
      mapping: hd(listing.listing_variants)
    }
  end

  test "opens an authorized threshold campaign with locked price and refund terms", ctx do
    assert {:ok, campaign} = GroupBuys.create(ctx.actor, ctx.store.id, attrs(ctx))
    assert campaign.status == :draft
    assert campaign.terms["automatic_refund_if_threshold_missed"]
    assert campaign.unit_price == 6_000

    assert {:ok, opened} = GroupBuys.open(ctx.actor, ctx.store.id, campaign.id)
    assert opened.status == :open
  end

  test "rejects a price below supplier floor and cross-store creation", ctx do
    assert {:error, :price_below_supplier_floor} =
             GroupBuys.create(ctx.actor, ctx.store.id, Map.put(attrs(ctx), :unit_price, 4_999))

    {other_actor, other_store} = create_merchant_with_store!()
    assert {:error, :forbidden} = GroupBuys.create(other_actor, other_store.id, attrs(ctx))
  end

  test "counts only successful exact payments and funds at the threshold", ctx do
    {:ok, campaign} = GroupBuys.create(ctx.actor, ctx.store.id, attrs(ctx))
    {:ok, campaign} = GroupBuys.open(ctx.actor, ctx.store.id, campaign.id)
    customer = create_customer!(ctx.store)

    assert {:ok, commitment} = GroupBuys.reserve(campaign.id, customer.id, 3)
    assert commitment.amount == 18_000

    payment =
      Emakola.Payments.create_payment!(
        %{
          store_id: ctx.store.id,
          amount: 18_000,
          gateway: :paystack,
          gateway_reference: "group-buy-#{Ecto.UUID.generate()}"
        },
        authorize?: false
      )

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    assert {:ok, paid} = GroupBuys.confirm_paid(commitment.id, payment)
    assert paid.status == :paid
    funded = Ash.get!(Emakola.Suppliers.GroupBuyCampaign, campaign.id, authorize?: false)
    assert funded.committed_quantity == 3
    assert funded.status == :funded
  end

  test "automatically refunds paid commitments after an under-threshold deadline", ctx do
    {:ok, campaign} = GroupBuys.create(ctx.actor, ctx.store.id, attrs(ctx))
    {:ok, campaign} = GroupBuys.open(ctx.actor, ctx.store.id, campaign.id)
    customer = create_customer!(ctx.store)
    {:ok, commitment} = GroupBuys.reserve(campaign.id, customer.id, 1)

    payment =
      Emakola.Payments.create_payment!(
        %{
          store_id: ctx.store.id,
          amount: 6_000,
          gateway: :paystack,
          gateway_reference: "group-refund-#{Ecto.UUID.generate()}"
        },
        authorize?: false
      )

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    {:ok, _paid} = GroupBuys.confirm_paid(commitment.id, payment)

    past = DateTime.add(DateTime.utc_now(), -60, :second)

    Emakola.Repo.update_all(
      from(c in "earn_group_buy_campaigns", where: c.id == type(^campaign.id, Ecto.UUID)),
      set: [deadline: past]
    )

    assert {:ok, _summary} =
             GroupBuys.expire_and_refund(campaign.id, Emakola.Payments.Gateways.Mock)

    assert Ash.get!(Emakola.Suppliers.GroupBuyCommitment, commitment.id, authorize?: false).status ==
             :refunded

    assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status == :refunded

    assert Ash.get!(Emakola.Suppliers.GroupBuyCampaign, campaign.id, authorize?: false).status ==
             :refunded

    assert {:ok, %{results: [{:skipped, _, :refunded}]}} =
             GroupBuys.expire_and_refund(campaign.id, Emakola.Payments.Gateways.Mock)
  end

  test "expiry worker refunds a due campaign through the configured gateway", ctx do
    {:ok, campaign} = GroupBuys.create(ctx.actor, ctx.store.id, attrs(ctx))
    {:ok, campaign} = GroupBuys.open(ctx.actor, ctx.store.id, campaign.id)
    customer = create_customer!(ctx.store)
    {:ok, commitment} = GroupBuys.reserve(campaign.id, customer.id, 1)

    payment =
      Emakola.Payments.create_payment!(
        %{
          store_id: ctx.store.id,
          amount: commitment.amount,
          gateway: :paystack,
          gateway_reference: "group-worker-#{Ecto.UUID.generate()}"
        },
        authorize?: false
      )
      |> Ash.Changeset.for_update(:mark_success, %{})
      |> Ash.update!(authorize?: false)

    {:ok, _paid} = GroupBuys.confirm_paid(commitment.id, payment)
    past = DateTime.add(DateTime.utc_now(), -60, :second)

    Emakola.Repo.update_all(
      from(c in "earn_group_buy_campaigns", where: c.id == type(^campaign.id, Ecto.UUID)),
      set: [deadline: past]
    )

    assert :ok =
             GroupBuyExpiryWorker.perform(%Oban.Job{args: %{"campaign_id" => campaign.id}})

    assert Ash.get!(Emakola.Suppliers.GroupBuyCommitment, commitment.id, authorize?: false).status ==
             :refunded

    assert Ash.get!(Emakola.Payments.Payment, payment.id, authorize?: false).status == :refunded
  end

  defp attrs(ctx) do
    deadline = DateTime.add(DateTime.utc_now(), 7, :day)

    %{
      listing_id: ctx.listing.id,
      listing_variant_id: ctx.mapping.id,
      title: "Three-bag group buy",
      threshold_quantity: 3,
      unit_price: 6_000,
      deadline: deadline,
      refund_deadline: DateTime.add(deadline, 2, :day)
    }
  end
end
