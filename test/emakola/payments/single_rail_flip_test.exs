defmodule Emakola.Payments.SingleRailFlipTest do
  @moduledoc """
  P1 exit invariants (spec §3.5): every new charge settles internal — ledger
  rows sum to the charge, a platform-fee row is always present, no gateway
  shares are produced, amounts are identical to the old gateway math.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

  alias Emakola.Payments.OrderSettlement

  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  describe "own-stock orders" do
    test "a VERIFIED merchant's charge settles internal with identical amounts" do
      merchant = create_store!(name: "Verified Own-Stock")
      verified_payout!(merchant, "ACCT_verified")
      product = create_product!(merchant, title: "Flip Product")
      own = create_variant!(product, merchant, price: 5_000, sku: "FLIP-OWN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 2}],
          []
        )

      # Verification no longer routes to the gateway: same fee math
      # (2% of 10_000), but internal — no shares, no subaccount.
      assert {:split, %{mode: :internal, total: 10_000, shares: [], allocations: allocs}} =
               OrderSettlement.prepare(order.id, merchant.id)

      by_role = Map.new(allocs, &{&1.role, &1})
      assert by_role[:merchant].amount == 9_800
      assert by_role[:merchant].subaccount_code == nil
      assert by_role[:platform].amount == 200
      assert Enum.all?(allocs, &(&1.settlement_method == :internal_hold))
      assert 10_000 == Enum.sum(Enum.map(allocs, & &1.amount))
    end
  end

  describe "dropship orders" do
    test "a fully-verified dropship charge settles internal — no gateway shares" do
      dropshipper = create_store!(name: "Dropshipper")
      verified_payout!(dropshipper, "ACCT_drop")
      product = create_product!(dropshipper, title: "Settle Product")

      wholesaler = create_store!(name: "Wholesaler")
      verified_payout!(wholesaler, "ACCT_whole")
      supplier = create_supplier!(dropshipper, name: "Linked", linked_store_id: wholesaler.id)

      drop =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "S-DROP",
          supplier_id: supplier.id,
          cost_price: 800
        )

      own = create_variant!(product, dropshipper, price: 3_000, sku: "S-OWN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          dropshipper.id,
          [%{variant_id: drop.id, quantity: 2}, %{variant_id: own.id, quantity: 1}],
          []
        )

      assert {:split, %{mode: :internal, shares: [], allocations: allocs}} =
               OrderSettlement.prepare(order.id, dropshipper.id)

      assert Enum.any?(allocs, &(&1.role == :platform and &1.amount > 0))
      assert Enum.all?(allocs, &(&1.settlement_method == :internal_hold))
      assert Enum.all?(allocs, &is_nil(&1.subaccount_code))
    end
  end

  describe "P1 exit invariant — persisted charges" do
    test "a persisted charge has rows that sum to it, including the platform fee" do
      merchant = create_store!(name: "Persist Flip")
      verified_payout!(merchant, "ACCT_persist")
      product = create_product!(merchant, title: "Persist Product")

      own =
        create_variant!(product, merchant, price: 7_500, sku: "FLIP-PERSIST", stock_quantity: 5)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 1}],
          []
        )

      settlement = OrderSettlement.prepare(order.id, merchant.id)
      assert {:split, %{mode: :internal}} = settlement

      {:ok, payment} =
        OrderSettlement.persist_payment(
          %{
            store_id: merchant.id,
            order_id: order.id,
            amount: order.total,
            currency: "GHS",
            gateway: :paystack,
            gateway_reference: "flip-#{order.id}",
            split_mode: :internal
          },
          settlement
        )

      {:ok, splits} = Emakola.Payments.list_payment_splits(payment.id, authorize?: false)

      assert order.total == Enum.sum(Enum.map(splits, & &1.amount))
      assert Enum.any?(splits, &(&1.role == :platform and &1.amount > 0))
      assert Enum.all?(splits, &(&1.settlement_method == :internal_hold))
    end
  end
end
