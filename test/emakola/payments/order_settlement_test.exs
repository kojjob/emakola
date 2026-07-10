defmodule Emakola.Payments.OrderSettlementTest do
  @moduledoc """
  Order-aware glue for SP5: loads a placed order's line items, asks
  DropshipSettlement for a split, exposes gateway shares for payment
  initiation, and persists the resulting PaymentSplit records.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  alias Emakola.Payments.OrderSettlement

  defp verified_payout!(store, code) do
    Emakola.Stores.StorePayoutAccount
    |> Ash.Changeset.for_create(:create, %{store_id: store.id})
    |> Ash.create!(authorize?: false)
    |> Ash.Changeset.for_update(:record_subaccount, %{subaccount_code: code})
    |> Ash.update!(authorize?: false)
  end

  setup do
    dropshipper = create_store!(name: "Dropshipper")
    verified_payout!(dropshipper, "ACCT_drop")
    product = create_product!(dropshipper, title: "Settle Product")
    {:ok, dropshipper: dropshipper, product: product}
  end

  describe "prepare/2 — linked wholesaler" do
    setup %{dropshipper: dropshipper, product: product} do
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

      {:ok, order: order, wholesaler: wholesaler}
    end

    test "returns gateway shares routing each party to its subaccount", %{
      dropshipper: dropshipper,
      order: order
    } do
      assert {:split, %{total: 13_000, shares: shares, allocations: allocs}} =
               OrderSettlement.prepare(order.id, dropshipper.id)

      assert %{subaccount: "ACCT_whole", share: 1_600} in shares
      assert %{subaccount: "ACCT_drop", share: 10_560} in shares
      # Platform's cut stays in the main account — never a share.
      refute Enum.any?(shares, &(&1.share == 840))
      assert length(allocs) == 3
    end

    test "record_splits! persists one PaymentSplit per allocation", %{
      dropshipper: dropshipper,
      order: order
    } do
      {:split, %{allocations: allocs}} = OrderSettlement.prepare(order.id, dropshipper.id)
      payment = create_payment!(dropshipper, order_id: order.id, amount: 13_000)

      :ok = OrderSettlement.record_splits!(payment, allocs)

      {:ok, splits} =
        Emakola.Payments.PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      assert length(splits) == 3
      by_role = Map.new(splits, &{&1.role, &1})
      assert by_role[:wholesaler].amount == 1_600
      assert by_role[:wholesaler].subaccount_code == "ACCT_whole"
      assert by_role[:platform].amount == 840
      assert by_role[:dropshipper].amount == 10_560
    end

    test "nets an older refund liability from the recipient's gateway share", %{
      dropshipper: dropshipper,
      wholesaler: wholesaler,
      order: order
    } do
      liability = refundable_liability!(dropshipper, wholesaler, 600)

      assert {:split, %{total: 13_000, shares: shares, allocations: allocations}} =
               OrderSettlement.prepare(order.id, dropshipper.id)

      assert %{subaccount: "ACCT_whole", share: 1_000} in shares

      by_role = Map.new(allocations, &{&1.role, &1})
      assert by_role.wholesaler.recovery_amount == 600
      assert by_role.platform.amount == 1_440
      assert Enum.sum(Enum.map(allocations, & &1.amount)) == 13_000

      updated = Ash.get!(Emakola.Payments.PaymentSplit, liability.id, authorize?: false)
      assert updated.reserved_recovery_amount == 600
    end
  end

  describe "prepare/2 — reconciles to order total" do
    test "adds delivery fee to the dropshipper share so shares sum to order.total", %{
      dropshipper: dropshipper,
      product: product
    } do
      wholesaler = create_store!(name: "Wholesaler 2")
      verified_payout!(wholesaler, "ACCT_whole2")
      supplier = create_supplier!(dropshipper, name: "Linked2", linked_store_id: wholesaler.id)

      drop =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "S-DEL",
          supplier_id: supplier.id,
          cost_price: 800
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          dropshipper.id,
          [%{variant_id: drop.id, quantity: 2}],
          delivery_fee: 1_500
        )

      assert {:split, %{total: total, shares: shares, allocations: allocs}} =
               OrderSettlement.prepare(order.id, dropshipper.id)

      # subtotal 10000 + delivery 1500 = 11500 = order.total
      assert total == 11_500
      # dropshipper margin 7560 + delivery 1500 = 9060
      assert %{role: :dropshipper, amount: 9_060} = Enum.find(allocs, &(&1.role == :dropshipper))
      assert %{subaccount: "ACCT_drop", share: 9_060} in shares
      # Wholesaler cost + dropshipper share + platform fee == the actual charge.
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end
  end

  describe "prepare/2 — platform fee on normal orders" do
    test "splits an own-stock order: merchant net to subaccount, platform keeps the fee", %{
      dropshipper: merchant,
      product: product
    } do
      # `merchant` already has a verified subaccount ("ACCT_drop") from setup.
      own = create_variant!(product, merchant, price: 5_000, sku: "PF-OWN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 2}],
          []
        )

      assert {:split, %{mode: :platform_fee, total: 10_000, shares: shares, allocations: allocs}} =
               OrderSettlement.prepare(order.id, merchant.id)

      # 2% of 10_000 = 200 fee, 9_800 net.
      assert %{subaccount: "ACCT_drop", share: 9_800} in shares
      # The platform's cut is the remainder — never a gateway share.
      refute Enum.any?(shares, &(&1.share == 200))

      by_role = Map.new(allocs, &{&1.role, &1})
      assert by_role[:merchant].amount == 9_800
      assert by_role[:merchant].subaccount_code == "ACCT_drop"
      assert by_role[:platform].amount == 200
      assert by_role[:platform].subaccount_code == nil
      # No money created or lost.
      assert 10_000 == Enum.sum(Enum.map(allocs, & &1.amount))
    end

    test "record_splits! persists the merchant and platform rows", %{
      dropshipper: merchant,
      product: product
    } do
      own = create_variant!(product, merchant, price: 5_000, sku: "PF-REC", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 2}],
          []
        )

      {:split, %{allocations: allocs}} = OrderSettlement.prepare(order.id, merchant.id)
      payment = create_payment!(merchant, order_id: order.id, amount: 10_000)

      :ok = OrderSettlement.record_splits!(payment, allocs)

      {:ok, splits} =
        Emakola.Payments.PaymentSplit
        |> Ash.Query.for_read(:by_payment, %{payment_id: payment.id})
        |> Ash.read(authorize?: false)

      by_role = Map.new(splits, &{&1.role, &1})
      assert by_role[:merchant].amount == 9_800
      assert by_role[:merchant].subaccount_code == "ACCT_drop"
      assert by_role[:platform].amount == 200
    end

    test "an own-stock order with no verified subaccount yields no split" do
      merchant = create_store!(name: "No Payout")
      product = create_product!(merchant, title: "No Payout Product")
      own = create_variant!(product, merchant, price: 5_000, sku: "PF-NOPAY", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 1}],
          []
        )

      assert {:no_split, :payout_unverified} = OrderSettlement.prepare(order.id, merchant.id)
    end
  end

  describe "prepare/2 — fallback" do
    test "external (unlinked) supplier yields no split", %{
      dropshipper: dropshipper,
      product: product
    } do
      supplier = create_supplier!(dropshipper, name: "External")

      drop =
        create_variant!(product, dropshipper,
          price: 5_000,
          sku: "S-EXT",
          supplier_id: supplier.id,
          cost_price: 800
        )

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          dropshipper.id,
          [%{variant_id: drop.id, quantity: 1}],
          []
        )

      assert {:no_split, :supplier_not_linked} = OrderSettlement.prepare(order.id, dropshipper.id)
    end
  end

  defp refundable_liability!(tenant_store, recipient_store, reversed_amount) do
    payment = create_payment!(tenant_store)

    Emakola.Payments.create_payment_split!(
      %{
        store_id: tenant_store.id,
        payment_id: payment.id,
        role: :wholesaler,
        recipient_store_id: recipient_store.id,
        amount: 1_000
      },
      authorize?: false
    )
    |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
    |> Ash.update!(authorize?: false)
  end
end
