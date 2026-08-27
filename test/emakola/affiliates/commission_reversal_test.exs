defmodule Emakola.Affiliates.CommissionReversalTest do
  @moduledoc """
  A refunded order must take the commission back.

  Kojo chose commission-on-payment, which is the motivating choice for an
  affiliate but puts the whole weight on reversal: if a refund does not claw
  the commission back, the merchant refunds a buyer in full AND has paid an
  affiliate for the sale.

  These tests exist because "the reversal machinery is role-blind" was an
  assumption, and an assumption about money is worth exactly nothing until a
  test has run.
  """
  use Emakola.DataCase, async: false

  require Ash.Query

  import Emakola.Factory

  alias Emakola.Affiliates
  alias Emakola.Affiliates.Programme
  alias Emakola.Payments.{OrderSettlement, PaymentSplit, RefundLiability}

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

    %{store: store, order: order, payment: payment, affiliate: affiliate}
  end

  defp affiliate_split(payment) do
    PaymentSplit
    |> Ash.Query.filter(payment_id == ^payment.id and role == :affiliate)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp refund!(payment, amount) do
    payment
    |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: amount})
    |> Ash.update!(authorize?: false)
  end

  test "a full refund reverses the whole commission", ctx do
    assert %{amount: 10_000, reversed_amount: 0} = affiliate_split(ctx.payment)

    payment = refund!(ctx.payment, 100_000)
    splits = Emakola.Payments.list_payment_splits!(payment.id, authorize?: false)

    RefundLiability.reconcile!(payment, splits)

    split = affiliate_split(payment)

    assert split.reversed_amount == 10_000,
           "a fully refunded order left #{split.reversed_amount} of #{split.amount} " <>
             "commission standing — the merchant paid an affiliate for a sale that unwound"

    assert split.status in [:reversed, :partially_reversed]
  end

  test "a half refund reverses half the commission", ctx do
    payment = refund!(ctx.payment, 50_000)
    splits = Emakola.Payments.list_payment_splits!(payment.id, authorize?: false)

    RefundLiability.reconcile!(payment, splits)

    split = affiliate_split(payment)
    assert split.reversed_amount == 5_000
  end

  test "a reversed commission is no longer payable", ctx do
    # payable_internal requires `amount > reversed_amount`. If a fully
    # reversed row stayed claimable, a payout would send money the merchant
    # has already taken back.
    payment = refund!(ctx.payment, 100_000)
    splits = Emakola.Payments.list_payment_splits!(payment.id, authorize?: false)
    RefundLiability.reconcile!(payment, splits)

    payable =
      PaymentSplit
      |> Ash.Query.for_read(:payable_internal, %{
        recipient_store_id: ctx.affiliate.payout_store_id
      })
      |> Ash.read!(authorize?: false)

    assert payable == [],
           "a fully reversed commission is still claimable by a payout"
  end
end
