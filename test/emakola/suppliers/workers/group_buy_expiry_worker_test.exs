defmodule Emakola.Suppliers.Workers.GroupBuyExpiryWorkerTest do
  @moduledoc """
  Post-merge hardening (2026-07-11 review): the expiry worker must not
  double-enqueue a campaign, must surface failed refunds to Oban for retry,
  and its sweep must revisit cancelled campaigns with unfinished refunds.

  async: false — some tests swap the configured :payment_gateway.
  """

  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  import Ecto.Query
  import Emakola.Factory

  alias Emakola.Suppliers.{GroupBuys, ListingImporter, Network, Offers}
  alias Emakola.Suppliers.Workers.GroupBuyExpiryWorker

  defmodule FailingGateway do
    def process_refund(_reference, _amount), do: {:error, :gateway_down}
  end

  setup do
    {supplier_actor, supplier} = create_merchant_with_store!()
    {reseller_actor, reseller} = create_merchant_with_store!()
    product = create_product!(supplier, status: :active, title: "Worker Bag")
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

    {:ok, campaign} =
      GroupBuys.create(reseller_actor, reseller.id, %{
        listing_id: listing.id,
        listing_variant_id: hd(listing.listing_variants).id,
        title: "Worker correctness",
        threshold_quantity: 3,
        unit_price: 6_000,
        deadline: DateTime.add(DateTime.utc_now(), 7, :day),
        refund_deadline: DateTime.add(DateTime.utc_now(), 9, :day)
      })

    {:ok, campaign} = GroupBuys.open(reseller_actor, reseller.id, campaign.id)

    %{store: reseller, campaign: campaign, customer: create_customer!(reseller)}
  end

  test "per-campaign jobs are unique — a duplicate insert is a no-op", ctx do
    %{campaign_id: ctx.campaign.id} |> GroupBuyExpiryWorker.new() |> Oban.insert!()
    %{campaign_id: ctx.campaign.id} |> GroupBuyExpiryWorker.new() |> Oban.insert!()

    assert [_only_one] =
             all_enqueued(
               worker: GroupBuyExpiryWorker,
               args: %{campaign_id: ctx.campaign.id}
             )
  end

  test "returns an error (so Oban retries) when a refund fails", ctx do
    _paid = paid_commitment!(ctx)
    force_deadline_past!(ctx.campaign.id)

    previous = Application.get_env(:emakola, :payment_gateway)
    Application.put_env(:emakola, :payment_gateway, FailingGateway)
    on_exit(fn -> restore_gateway(previous) end)

    assert {:error, _reason} =
             GroupBuyExpiryWorker.perform(%Oban.Job{args: %{"campaign_id" => ctx.campaign.id}})
  end

  test "sweep re-enqueues cancelled campaigns whose refunds are unfinished", ctx do
    commitment = paid_commitment!(ctx)
    force_deadline_past!(ctx.campaign.id)
    force_campaign_status!(ctx.campaign.id, "cancelled")
    force_status!(commitment.id, "refund_failed")

    assert :ok = GroupBuyExpiryWorker.perform(%Oban.Job{args: %{}})

    assert_enqueued(
      worker: GroupBuyExpiryWorker,
      args: %{campaign_id: ctx.campaign.id}
    )
  end

  defp paid_commitment!(ctx) do
    {:ok, commitment} = GroupBuys.reserve(ctx.campaign.id, ctx.customer.id, 1)

    payment =
      Emakola.Payments.create_payment!(
        %{
          store_id: commitment.store_id,
          amount: commitment.amount,
          gateway: :paystack,
          gateway_reference: "gbw-#{Ecto.UUID.generate()}"
        },
        authorize?: false
      )

    commitment
    |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
    |> Ash.update!(authorize?: false)

    payment =
      payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)

    {:ok, paid} = GroupBuys.confirm_paid(commitment.id, payment)
    paid
  end

  defp restore_gateway(nil), do: Application.delete_env(:emakola, :payment_gateway)
  defp restore_gateway(previous), do: Application.put_env(:emakola, :payment_gateway, previous)

  defp force_deadline_past!(campaign_id) do
    past = DateTime.add(DateTime.utc_now(), -60, :second)

    Emakola.Repo.update_all(
      from(c in "earn_group_buy_campaigns", where: c.id == type(^campaign_id, Ecto.UUID)),
      set: [deadline: past]
    )
  end

  defp force_campaign_status!(campaign_id, status) do
    Emakola.Repo.update_all(
      from(c in "earn_group_buy_campaigns", where: c.id == type(^campaign_id, Ecto.UUID)),
      set: [status: status]
    )
  end

  defp force_status!(commitment_id, status) do
    Emakola.Repo.update_all(
      from(c in "earn_group_buy_commitments", where: c.id == type(^commitment_id, Ecto.UUID)),
      set: [status: status]
    )
  end
end
