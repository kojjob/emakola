defmodule Emakola.Affiliates.CommissionSettlementTest do
  @moduledoc """
  The carve as it actually runs — through `OrderSettlement`, producing real
  `PaymentSplit` rows.

  The unit tests prove the arithmetic. These prove it survives the machinery:
  that the sum invariant still holds, that the affiliate row is payable by the
  existing payout reads, and that a sales team settling on the same payment
  does not silently break.
  """
  use Emakola.DataCase, async: false

  require Ash.Query

  import Emakola.Factory

  alias Emakola.Affiliates
  alias Emakola.Affiliates.Programme
  alias Emakola.Payments.{OrderSettlement, PaymentSplit}

  # Same shape as finance_live_internal_test's local helper — a payment only
  # gets splits once it has actually succeeded.
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

    order = Ash.get!(Emakola.Orders.Order, order.id, authorize?: false)

    %{store: store, order: order, affiliate: affiliate, link: link}
  end

  test "the settled allocations still sum to the order total", ctx do
    case OrderSettlement.prepare(ctx.order.id, ctx.store.id) do
      {:split, %{allocations: allocations, total: total}} ->
        assert Enum.sum(Enum.map(allocations, & &1.amount)) == total

        affiliate_allocation = Enum.find(allocations, &(&1.role == :affiliate))
        assert affiliate_allocation, "no affiliate allocation was carved"
        assert affiliate_allocation.amount == 10_000
        assert affiliate_allocation.recipient_store_id == ctx.affiliate.payout_store_id

      other ->
        flunk("settlement did not split: #{inspect(other)}")
    end
  end

  test "the affiliate's money is claimable by the existing payout read", ctx do
    # The whole point of riding the split rail: payable_internal is what a
    # payout claims, and it excludes only :platform — so a new role is
    # payable by default. If this fails, the affiliate is owed money the
    # payout engine cannot see.
    payment = success_payment!(ctx.store, %{order_id: ctx.order.id, amount: 100_000})
    {:split, %{allocations: allocations}} = OrderSettlement.prepare(ctx.order.id, ctx.store.id)

    OrderSettlement.record_splits!(payment, allocations)

    splits =
      PaymentSplit
      |> Ash.Query.filter(payment_id == ^payment.id and role == :affiliate)
      |> Ash.read!(authorize?: false)

    assert [split] = splits
    assert split.amount == 10_000
    assert split.settlement_method == :internal_hold
    assert split.affiliate_id == ctx.affiliate.id
    assert split.recipient_store_id == ctx.affiliate.payout_store_id
  end

  test "recording twice does not pay the affiliate twice", ctx do
    payment = success_payment!(ctx.store, %{order_id: ctx.order.id, amount: 100_000})
    {:split, %{allocations: allocations}} = OrderSettlement.prepare(ctx.order.id, ctx.store.id)

    OrderSettlement.record_splits!(payment, allocations)
    OrderSettlement.record_splits!(payment, allocations)

    splits =
      PaymentSplit
      |> Ash.Query.filter(payment_id == ^payment.id and role == :affiliate)
      |> Ash.read!(authorize?: false)

    assert length(splits) == 1
  end

  test "a merchant/dropshipper split count of one is preserved", ctx do
    # SalesTeams.settlement_base/1 requires EXACTLY ONE :merchant/:dropshipper
    # split and returns :ineligible_settlement_base otherwise — which would
    # silently stop team settlements. The affiliate carve MODIFIES that row
    # rather than adding a second, so the count must stay 1. Nothing else in
    # the suite would catch a change here.
    payment = success_payment!(ctx.store, %{order_id: ctx.order.id, amount: 100_000})
    {:split, %{allocations: allocations}} = OrderSettlement.prepare(ctx.order.id, ctx.store.id)

    OrderSettlement.record_splits!(payment, allocations)

    base_splits =
      PaymentSplit
      |> Ash.Query.filter(payment_id == ^payment.id and role in [:merchant, :dropshipper])
      |> Ash.read!(authorize?: false)

    assert length(base_splits) == 1
    # And it is reduced by the commission, so a team settles on what the
    # merchant actually kept.
    assert hd(base_splits).amount < 100_000
  end
end
