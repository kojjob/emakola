defmodule Emakola.Affiliates.CommissionTest do
  @moduledoc """
  The carve: commission comes OUT of the merchant's allocation, never
  alongside it, because `OrderSettlement.sum_matches_total?/2` is enforced on
  both rails.

  Every test here is about money leaving one party and reaching another, so
  the failure modes are: paying someone who earned nothing, paying the wrong
  amount, or making the whole charge unrepresentable.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Affiliates
  alias Emakola.Affiliates.{Commission, Programme}

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

    %{
      store: store,
      product: product,
      variant: variant,
      affiliate: affiliate,
      link: link
    }
  end

  defp order_with(ctx, attribution, variant \\ nil) do
    variant = variant || ctx.variant

    order =
      Emakola.Orders.create_order!(
        %{
          store_id: ctx.store.id,
          total: 100_000,
          subtotal: 100_000,
          attribution: attribution
        },
        authorize?: false
      )

    Emakola.Orders.LineItem
    |> Ash.Changeset.for_create(:create, %{
      order_id: order.id,
      store_id: ctx.store.id,
      variant_id: variant.id,
      quantity: 1
    })
    |> Ash.create!(authorize?: false)

    Ash.get!(Emakola.Orders.Order, order.id, authorize?: false)
  end

  defp merchant_allocation(store, amount) do
    [%{role: :merchant, recipient_store_id: store.id, amount: amount}]
  end

  test "carves the rate out of the merchant's allocation", ctx do
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    carved = Commission.carve(merchant_allocation(ctx.store, 100_000), order)

    assert [merchant, affiliate] = carved
    # 10% of the sale, taken from the merchant — not added on top.
    assert affiliate.role == :affiliate
    assert affiliate.amount == 10_000
    assert merchant.amount == 90_000

    # The sum is what OrderSettlement enforces on both rails.
    assert Enum.sum(Enum.map(carved, & &1.amount)) == 100_000
  end

  test "the affiliate row is internal_hold, never a gateway share", ctx do
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    [_merchant, affiliate] = Commission.carve(merchant_allocation(ctx.store, 100_000), order)

    # default_settlement_method/1 returns :gateway_share for every non-platform
    # role, which would demand a Paystack subaccount the affiliate has not got.
    assert affiliate.settlement_method == :internal_hold
    assert affiliate.recipient_store_id == ctx.affiliate.payout_store_id
  end

  test "pays nothing when the order does not contain the promoted product", ctx do
    other = create_product!(ctx.store, status: :active, title: "Something Else")
    other_variant = create_variant!(other, ctx.store, stock_quantity: 5)
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token}, other_variant)

    allocations = merchant_allocation(ctx.store, 100_000)

    assert Commission.carve(allocations, order) == allocations
  end

  test "pays nothing when the token belongs to another shop", ctx do
    {_m2, other_store} = create_merchant_with_store!()

    # A token minted for shop A, sitting in a session, while the buyer checks
    # out at shop B. Without a store check this carves from shop B.
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})
    allocations = merchant_allocation(other_store, 100_000)

    assert Commission.carve(allocations, order) == allocations
  end

  test "pays nothing with no token, an unknown token, or the programme off", ctx do
    allocations = merchant_allocation(ctx.store, 100_000)

    assert Commission.carve(allocations, order_with(ctx, %{})) == allocations

    assert Commission.carve(allocations, order_with(ctx, %{"affiliate_token" => "nope"})) ==
             allocations

    {:ok, _} = Programme.disable(ctx.store.id)
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})
    assert Commission.carve(allocations, order) == allocations
  end

  test "is a percentage of the SALE, then capped at what the merchant can bear", ctx do
    # The order is 100_000 and the rate 10%, so 10_000 is owed — but this
    # merchant's allocation is only 3_000 (a thin margin, or costs taken
    # first). The affiliate gets what there is, and the row lands at zero
    # rather than negative.
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    carved = Commission.carve(merchant_allocation(ctx.store, 3_000), order)

    assert [merchant, affiliate] = carved
    assert affiliate.amount == 3_000
    assert merchant.amount == 0
  end

  test "the rate is not quietly reduced by the platform fee", ctx do
    # A merchant advertising 10% on a 100_000 sale owes 10_000, even though
    # their own allocation is 98_000 after the platform fee. Computing on the
    # allocation would pay 9_800 — a shortfall that varies per order and
    # cannot be explained to the affiliate.
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    [_merchant, affiliate] = Commission.carve(merchant_allocation(ctx.store, 98_000), order)

    assert affiliate.amount == 10_000
  end

  test "never drives an allocation negative", ctx do
    # The floor is defence in depth: the rate is capped below 100% and this
    # carve runs first, so it should be unreachable. finalize_internal refuses
    # the whole charge on a negative row, so "unreachable" is not good enough.
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    for amount <- [0, 1, 7, 100_000] do
      carved = Commission.carve(merchant_allocation(ctx.store, amount), order)

      refute Enum.any?(carved, &(&1.amount < 0)),
             "a #{amount} allocation produced a negative row"

      assert Enum.sum(Enum.map(carved, & &1.amount)) == amount
    end
  end

  test "carves nothing rather than a zero row when nothing is left", ctx do
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})
    allocations = merchant_allocation(ctx.store, 0)

    assert Commission.carve(allocations, order) == allocations
  end

  test "leaves a dropshipper allocation carveable too", ctx do
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    carved =
      Commission.carve(
        [%{role: :dropshipper, recipient_store_id: ctx.store.id, amount: 100_000}],
        order
      )

    assert [reseller, affiliate] = carved
    assert reseller.amount == 90_000
    assert affiliate.amount == 10_000
  end

  test "never touches the platform's allocation", ctx do
    order = order_with(ctx, %{"affiliate_token" => ctx.link.token})

    allocations = [
      %{role: :platform, recipient_store_id: nil, amount: 2_000},
      %{role: :merchant, recipient_store_id: ctx.store.id, amount: 98_000}
    ]

    carved = Commission.carve(allocations, order)

    platform = Enum.find(carved, &(&1.role == :platform))
    assert platform.amount == 2_000
  end
end
