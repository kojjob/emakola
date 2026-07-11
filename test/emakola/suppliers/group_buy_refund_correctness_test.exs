defmodule Emakola.Suppliers.GroupBuyRefundCorrectnessTest do
  @moduledoc """
  Post-merge hardening (2026-07-11 review): every path that can leave a
  customer's successful group-buy payment unrefunded must instead converge
  on :refunded. True cross-process races can't run under the SQL sandbox,
  so these tests pin the structural guarantees the fix relies on: refunds
  dispatch on the FRESH row status under FOR UPDATE, never a caller struct.
  """

  use Emakola.DataCase, async: true

  import Ecto.Query
  import Emakola.Factory

  alias Emakola.Suppliers.{GroupBuyCampaign, GroupBuyCommitment, GroupBuys}
  alias Emakola.Suppliers.{ListingImporter, Network, Offers}

  defmodule SelfReportingGateway do
    @moduledoc "Runs in the caller's process; reports every refund to the test pid."
    def process_refund(reference, amount) do
      send(self(), {:refund_called, reference, amount})
      {:ok, %{refund_reference: "REF-#{reference}"}}
    end
  end

  defmodule FailingGateway do
    def process_refund(_reference, _amount), do: {:error, :gateway_down}
  end

  setup do
    {supplier_actor, supplier} = create_merchant_with_store!()
    {reseller_actor, reseller} = create_merchant_with_store!()
    product = create_product!(supplier, status: :active, title: "Refund Bag")
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
        title: "Refund correctness",
        threshold_quantity: 3,
        unit_price: 6_000,
        deadline: DateTime.add(DateTime.utc_now(), 7, :day),
        refund_deadline: DateTime.add(DateTime.utc_now(), 9, :day)
      })

    {:ok, campaign} = GroupBuys.open(reseller_actor, reseller.id, campaign.id)

    %{store: reseller, campaign: campaign, customer: create_customer!(reseller)}
  end

  describe "late successful payments are refunded, never confiscated" do
    test "charge.success landing after the commitment was cancelled triggers a refund", ctx do
      {:ok, commitment} = GroupBuys.reserve(ctx.campaign.id, ctx.customer.id, 1)
      payment = attach_payment!(commitment)
      force_deadline_past!(ctx.campaign.id)

      # Sweep runs before the webhook: cancels the pending commitment.
      {:ok, _summary} = GroupBuys.expire_and_refund(ctx.campaign.id, SelfReportingGateway)
      assert reload(GroupBuyCommitment, commitment.id).status == :cancelled

      # Now the late webhook arrives with a successful charge.
      payment = mark_success!(payment)
      GroupBuys.confirm_payment(payment, SelfReportingGateway)

      assert_received {:refund_called, _reference, 6_000}
      assert reload(GroupBuyCommitment, commitment.id).status == :refunded
      assert reload(Emakola.Payments.Payment, payment.id).status == :refunded
    end

    test "charge.success landing after the deadline (commitment still pending) refunds", ctx do
      {:ok, commitment} = GroupBuys.reserve(ctx.campaign.id, ctx.customer.id, 1)
      payment = attach_payment!(commitment)
      force_deadline_past!(ctx.campaign.id)

      # No sweep yet — the campaign is past its deadline but still :open.
      payment = mark_success!(payment)
      GroupBuys.confirm_payment(payment, SelfReportingGateway)

      assert_received {:refund_called, _reference, 6_000}
      assert reload(GroupBuyCommitment, commitment.id).status == :refunded
      assert reload(Emakola.Payments.Payment, payment.id).status == :refunded
    end
  end

  describe "crash recovery for stranded :refunding commitments" do
    test "a :refunding commitment whose payment was never refunded is re-attempted", ctx do
      commitment = paid_commitment!(ctx)
      force_deadline_past!(ctx.campaign.id)
      force_status!(commitment.id, "refunding")

      {:ok, _summary} = GroupBuys.expire_and_refund(ctx.campaign.id, SelfReportingGateway)

      assert_received {:refund_called, _reference, 6_000}
      assert reload(GroupBuyCommitment, commitment.id).status == :refunded
      assert reload(Emakola.Payments.Payment, commitment.payment_id).status == :refunded

      assert reload(GroupBuyCampaign, ctx.campaign.id).status == :refunded
    end

    test "a :refunding commitment whose payment is already :refunded completes without a second gateway call",
         ctx do
      commitment = paid_commitment!(ctx)
      force_deadline_past!(ctx.campaign.id)
      force_status!(commitment.id, "refunding")

      reload(Emakola.Payments.Payment, commitment.payment_id)
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 6_000})
      |> Ash.update!(authorize?: false)

      {:ok, _summary} = GroupBuys.expire_and_refund(ctx.campaign.id, SelfReportingGateway)

      refute_received {:refund_called, _, _}
      assert reload(GroupBuyCommitment, commitment.id).status == :refunded
    end
  end

  describe "failed refunds are retried, not terminal" do
    test "a :refund_failed commitment is retried on the next run", ctx do
      commitment = paid_commitment!(ctx)
      force_deadline_past!(ctx.campaign.id)

      {:ok, %{results: results}} = GroupBuys.expire_and_refund(ctx.campaign.id, FailingGateway)
      assert Enum.any?(results, &match?({:error, _, _}, &1))
      assert reload(GroupBuyCommitment, commitment.id).status == :refund_failed

      {:ok, _summary} = GroupBuys.expire_and_refund(ctx.campaign.id, SelfReportingGateway)

      assert_received {:refund_called, _reference, 6_000}
      assert reload(GroupBuyCommitment, commitment.id).status == :refunded
      assert reload(GroupBuyCampaign, ctx.campaign.id).status == :refunded
    end
  end

  describe "stale-struct claims are impossible" do
    test "an already :refunded commitment is skipped even when the sweep re-runs", ctx do
      commitment = paid_commitment!(ctx)
      force_deadline_past!(ctx.campaign.id)

      {:ok, _} = GroupBuys.expire_and_refund(ctx.campaign.id, SelfReportingGateway)
      assert_received {:refund_called, _, _}

      {:ok, %{results: results}} =
        GroupBuys.expire_and_refund(ctx.campaign.id, SelfReportingGateway)

      refute_received {:refund_called, _, _}
      assert [{:skipped, _, :refunded}] = results
      assert reload(GroupBuyCommitment, commitment.id).status == :refunded
    end
  end

  describe "escrow: group-buy money never reaches merchant payouts early" do
    test "customer payments are created payout_held", ctx do
      {:ok, result} =
        GroupBuys.initiate_customer_payment(
          ctx.campaign.id,
          ctx.customer,
          1,
          "https://shop.example/return"
        )

      assert result.payment.payout_held
    end

    test "payout holds are released when the campaign funds", ctx do
      {:ok, result} =
        GroupBuys.initiate_customer_payment(
          ctx.campaign.id,
          ctx.customer,
          3,
          "https://shop.example/return"
        )

      payment = mark_success!(result.payment)
      {:ok, _paid} = GroupBuys.confirm_payment(payment)

      assert reload(GroupBuyCampaign, ctx.campaign.id).status == :funded
      refute reload(Emakola.Payments.Payment, payment.id).payout_held
    end
  end

  defp paid_commitment!(ctx) do
    {:ok, commitment} = GroupBuys.reserve(ctx.campaign.id, ctx.customer.id, 1)
    payment = attach_payment!(commitment) |> mark_success!()
    {:ok, paid} = GroupBuys.confirm_paid(commitment.id, payment)
    paid
  end

  defp attach_payment!(commitment) do
    payment =
      Emakola.Payments.create_payment!(
        %{
          store_id: commitment.store_id,
          amount: commitment.amount,
          gateway: :paystack,
          gateway_reference: "grc-#{Ecto.UUID.generate()}"
        },
        authorize?: false
      )

    commitment
    |> Ash.Changeset.for_update(:attach_payment, %{payment_id: payment.id})
    |> Ash.update!(authorize?: false)

    payment
  end

  defp mark_success!(payment) do
    payment |> Ash.Changeset.for_update(:mark_success, %{}) |> Ash.update!(authorize?: false)
  end

  defp force_deadline_past!(campaign_id) do
    past = DateTime.add(DateTime.utc_now(), -60, :second)

    Emakola.Repo.update_all(
      from(c in "earn_group_buy_campaigns", where: c.id == type(^campaign_id, Ecto.UUID)),
      set: [deadline: past]
    )
  end

  defp force_status!(commitment_id, status) do
    Emakola.Repo.update_all(
      from(c in "earn_group_buy_commitments", where: c.id == type(^commitment_id, Ecto.UUID)),
      set: [status: status]
    )
  end

  defp reload(resource, id), do: Ash.get!(resource, id, authorize?: false)
end
