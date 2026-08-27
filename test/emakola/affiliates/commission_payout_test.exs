defmodule Emakola.Affiliates.CommissionPayoutTest do
  @moduledoc """
  The last leg: an affiliate's commission becomes a payout they can be paid.

  The whole shell-store design was justified by "the existing payout rail
  then works unchanged". This is the test that makes that a fact rather than
  a claim — `prepare_internal_payout/1` is what a platform approval actually
  calls, and it resolves the destination from a store.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Affiliates
  alias Emakola.Affiliates.Programme
  alias Emakola.Payments.{OrderSettlement, PayoutService}

  defp success_payment!(store, attrs) do
    store
    |> Emakola.Factory.create_payment!(attrs)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
  end

  setup do
    {_merchant, store} = create_merchant_with_store!()
    product = create_product!(store, status: :active, title: "Kente Cloth")
    variant = create_variant!(product, store, stock_quantity: 10)

    {:ok, affiliate} =
      Affiliates.register(%{
        phone: "0201234567",
        name: "Ama",
        momo_number: "0201234567",
        momo_provider: "mtn"
      })

    {:ok, _programme} = Programme.enable(store.id, 1_000)
    {:ok, link} = Programme.link_for(affiliate, store.id, product.id)

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: store.id,
          total: 100_000,
          subtotal: 100_000,
          attribution: %{"affiliate_token" => link.token}
        },
        authorize?: false
      )

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    payment = success_payment!(store, %{order_id: order.id, amount: 100_000})
    {:split, %{allocations: allocations}} = OrderSettlement.prepare(order.id, store.id)
    OrderSettlement.record_splits!(payment, allocations)

    # Splits are written :pending and only become payable once the payment
    # webhook marks them settled (charge.success). Without this step nothing
    # is claimable — which is correct, and worth stating: an affiliate is
    # owed money only after the money has actually arrived.
    for split <- Emakola.Payments.list_payment_splits!(payment.id, authorize?: false) do
      split
      |> Ash.Changeset.for_update(:mark_settled, %{})
      |> Ash.update!(authorize?: false)
    end

    %{store: store, affiliate: affiliate, payment: payment}
  end

  test "an affiliate's commission becomes a payout for their MoMo number", ctx do
    assert {:ok, payout} = PayoutService.prepare_internal_payout(ctx.affiliate.payout_store_id)

    assert payout.amount == 10_000
    assert payout.store_id == ctx.affiliate.payout_store_id
    assert payout.status == :pending
  end

  test "the transfer destination is the affiliate's own MoMo number", ctx do
    assert {:ok, destination} = PayoutService.transfer_destination(ctx.affiliate.payout_store_id)

    assert destination.account_number == "0201234567"
    assert destination.bank_code == "MTN"
  end

  test "preparing twice does not pay the same commission twice", ctx do
    assert {:ok, _first} = PayoutService.prepare_internal_payout(ctx.affiliate.payout_store_id)

    # The first payout claimed the split (paid_out_at is stamped), so there is
    # nothing outstanding left to claim.
    assert {:error, _nothing_outstanding} =
             PayoutService.prepare_internal_payout(ctx.affiliate.payout_store_id)
  end
end
