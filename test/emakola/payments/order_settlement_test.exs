defmodule Emakola.Payments.OrderSettlementTest do
  @moduledoc """
  Order-aware glue for SP5: loads a placed order's line items, asks
  DropshipSettlement for a split, exposes gateway shares for payment
  initiation, and persists the resulting PaymentSplit records.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  import ExUnit.CaptureLog

  alias Emakola.Payments.OrderSettlement
  alias Emakola.Suppliers.{ListingImporter, Network, Offers}

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

    test "zero-fee order split output is byte-identical to the pre-fee math", %{
      dropshipper: dropshipper,
      order: order
    } do
      assert {:split, %{allocations: allocs}} = OrderSettlement.prepare(order.id, dropshipper.id)

      actual =
        allocs
        |> Enum.map(&Map.take(&1, [:role, :amount, :subaccount_code]))
        |> Enum.sort_by(& &1.role)

      expected =
        Enum.sort_by(
          [
            %{role: :wholesaler, amount: 1_600, subaccount_code: "ACCT_whole"},
            %{role: :platform, amount: 840},
            %{role: :dropshipper, amount: 10_560, subaccount_code: "ACCT_drop"}
          ],
          & &1.role
        )

      assert actual == expected
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

    test "buyer_protection_enabled ON does not prevent a dropship split from winning", %{
      dropshipper: dropshipper,
      order: order
    } do
      dropshipper
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

      assert {:split, %{mode: :dropship_split}} =
               OrderSettlement.prepare(order.id, dropshipper.id)
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

    # Regression pin (TC-2 Task 4, case iii): buyer_protection_enabled defaults
    # to false, so this must keep returning exactly what it returned before
    # the hold-mode branch existed — byte-identical to the assertions above.
    test "buyer_protection default OFF: platform-fee settlement is unaffected (regression pin)",
         %{dropshipper: merchant, product: product} do
      own = create_variant!(product, merchant, price: 5_000, sku: "PF-PIN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 1}],
          []
        )

      assert {:split,
              %{
                mode: :platform_fee,
                total: 5_000,
                shares: [%{subaccount: "ACCT_drop", share: 4_900}],
                allocations: allocs
              }} = OrderSettlement.prepare(order.id, merchant.id)

      by_role = Map.new(allocs, &{&1.role, &1})
      assert by_role.merchant.amount == 4_900
      assert by_role.merchant.subaccount_code == "ACCT_drop"
      assert by_role.platform.amount == 100
      assert by_role.platform.subaccount_code == nil
    end
  end

  describe "prepare/2 — buyer protection hold (TC-2)" do
    test "toggle ON + own-stock order → prepare returns a hold", %{
      dropshipper: merchant,
      product: product
    } do
      merchant
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

      own = create_variant!(product, merchant, price: 5_000, sku: "PROT-OWN", stock_quantity: 20)

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          merchant.id,
          [%{variant_id: own.id, quantity: 1}],
          []
        )

      assert {:hold, :buyer_protection} = OrderSettlement.prepare(order.id, merchant.id)
    end

    test "pay-link protected: false on a protection-enabled store → no hold", %{
      dropshipper: merchant
    } do
      merchant
      |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
      |> Ash.update!(authorize?: false)

      link =
        Emakola.Orders.PayLink
        |> Ash.Changeset.for_create(:create, %{
          store_id: merchant.id,
          type: :custom,
          title: "Deal",
          amount: 4_000,
          protected: false
        })
        |> Ash.create!(authorize?: false)

      order = create_order!(merchant, %{pay_link_id: link.id, total: 4_000})

      refute match?({:hold, _}, OrderSettlement.prepare(order.id, merchant.id))
    end

    test "pay-link protected: true on a protection-disabled store → hold", %{
      dropshipper: merchant
    } do
      link =
        Emakola.Orders.PayLink
        |> Ash.Changeset.for_create(:create, %{
          store_id: merchant.id,
          type: :custom,
          title: "Deal",
          amount: 4_000,
          protected: true
        })
        |> Ash.create!(authorize?: false)

      order = create_order!(merchant, %{pay_link_id: link.id, total: 4_000})

      assert {:hold, :buyer_protection} = OrderSettlement.prepare(order.id, merchant.id)
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

  # -- Dispatch fees in splits --------------------------------------------
  # Real network flow (Offers -> publish -> ListingImporter) so the imported
  # variant carries a genuine ResellerListingVariant/offer chain for
  # dispatch_fees_for/3 to read — mirrors checkout_service_test.exs's
  # "dispatch fees" fixtures.

  describe "dispatch fees in splits" do
    setup do
      {reseller_actor, reseller} = create_merchant_with_store!(%{name: "Fee Split Reseller"})
      verified_payout!(reseller, "ACCT_fee_reseller")
      {:ok, reseller_actor: reseller_actor, reseller: reseller}
    end

    test "wholesaler share = cost + dispatch fee; platform fee base unchanged; sum invariant holds",
         %{reseller_actor: reseller_actor, reseller: reseller} do
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      items = [%{variant_id: drop.variant.id, quantity: 1}]

      assert {:ok, fee_order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra"
               )

      assert {:ok, no_fee_order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items, region: "volta")

      assert {:split, %{total: total, allocations: fee_allocs}} =
               OrderSettlement.prepare(fee_order.id, reseller.id)

      assert {:split, %{allocations: no_fee_allocs}} =
               OrderSettlement.prepare(no_fee_order.id, reseller.id)

      # wholesaler cost (4000) + dispatch fee (1500)
      assert %{amount: 5_500} = find_role(fee_allocs, :wholesaler)

      # Platform fee base is the dropship margin only — unaffected by the fee.
      assert find_role(fee_allocs, :platform).amount == find_role(no_fee_allocs, :platform).amount

      assert total == fee_order.total
      assert total == Enum.sum(Enum.map(fee_allocs, & &1.amount))
    end

    test "multi-supplier: each wholesaler gets exactly their own fee; sum invariant holds", %{
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      {wholesaler_a_actor, wholesaler_a} = create_dropship_wholesaler!(reseller_actor, reseller)
      {wholesaler_b_actor, wholesaler_b} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop_a =
        import_offer!(wholesaler_a_actor, wholesaler_a, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      drop_b =
        import_offer!(wholesaler_b_actor, wholesaler_b, reseller_actor, reseller, %{
          "Greater Accra" => 3_000
        })

      items = [
        %{variant_id: drop_a.variant.id, quantity: 1},
        %{variant_id: drop_b.variant.id, quantity: 1}
      ]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra"
               )

      assert {:split, %{total: total, allocations: allocs}} =
               OrderSettlement.prepare(order.id, reseller.id)

      wholesalers = Enum.filter(allocs, &(&1.role == :wholesaler))
      # cost 4000 + own dispatch fee, per supplier
      assert %{amount: 5_500} = Enum.find(wholesalers, &(&1.supplier_id == drop_a.supplier_id))
      assert %{amount: 7_000} = Enum.find(wholesalers, &(&1.supplier_id == drop_b.supplier_id))

      assert total == order.total
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end

    test "coupon discount: sum invariant still holds with fee + discount", %{
      reseller_actor: reseller_actor,
      reseller: reseller
    } do
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      items = [%{variant_id: drop.variant.id, quantity: 1}]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra"
               )

      # A cart carrying a dispatch fee is a network (Earn-imported) cart, and
      # coupons are categorically disallowed on those at checkout
      # (Emakola.Suppliers.NetworkCheckoutEligibility) — a pre-existing rule
      # unrelated to dispatch fees. Apply the discount directly to the order,
      # the same way CheckoutService itself does inside its transaction, to
      # exercise the settlement invariant with fee + discount both present.
      order =
        order
        |> Ash.Changeset.for_update(:update, %{
          discount_amount: 500,
          total: order.total - 500
        })
        |> Ash.update!(authorize?: false)

      assert {:split, %{total: total, allocations: allocs}} =
               OrderSettlement.prepare(order.id, reseller.id)

      assert total == order.total
      assert total == Enum.sum(Enum.map(allocs, & &1.amount))
    end

    # Promoted from a reviewer probe: pins the exact per-allocation numbers
    # (not just the sum invariant) for a cart mixing multiple suppliers,
    # delivery, discount, and dispatch fees all at once.
    test "multi-supplier + delivery + discount + fees: exact allocations, sum invariant holds",
         %{reseller_actor: reseller_actor, reseller: reseller} do
      {wa_actor, wa} = create_dropship_wholesaler!(reseller_actor, reseller)
      {wb_actor, wb} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop_a = import_offer!(wa_actor, wa, reseller_actor, reseller, %{"Greater Accra" => 1_500})
      drop_b = import_offer!(wb_actor, wb, reseller_actor, reseller, %{"Greater Accra" => 3_000})

      items = [
        %{variant_id: drop_a.variant.id, quantity: 1},
        %{variant_id: drop_b.variant.id, quantity: 1}
      ]

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(reseller.id, items,
                 region: "greater_accra",
                 delivery_fee: 1_000
               )

      # subtotal 10_000 (5_000 retail x2) + delivery 1_000 + fees (1_500+3_000)
      assert order.total == 15_500

      # Coupons are structurally forbidden on network carts
      # (NetworkCheckoutEligibility); apply the discount directly to the
      # order, the same way CheckoutService's own transaction does, to
      # exercise the invariant with fee + delivery + discount all present.
      order =
        order
        |> Ash.Changeset.for_update(:update, %{discount_amount: 500, total: order.total - 500})
        |> Ash.update!(authorize?: false)

      assert {:split, %{total: total, allocations: allocs}} =
               OrderSettlement.prepare(order.id, reseller.id)

      by = fn role -> Enum.filter(allocs, &(&1.role == role)) end
      w = fn sid -> Enum.find(by.(:wholesaler), &(&1.supplier_id == sid)) end

      # Hand-derived: retail 5_000 / cost 4_000 / margin 1_000 per supplier
      # line; bps 1_000 (10%) -> dropshipper net 900, platform fee 100 per
      # line.
      assert w.(drop_a.supplier_id).amount == 4_000 + 1_500
      assert w.(drop_b.supplier_id).amount == 4_000 + 3_000
      assert [%{amount: 200}] = by.(:platform)
      # dropshipper: margin net 900+900=1_800 + (delivery 1_000 - discount 500)
      assert [%{amount: 2_300}] = by.(:dropshipper)

      assert total == order.total
      assert total == 15_000
      assert Enum.sum(Enum.map(allocs, & &1.amount)) == order.total
    end

    # Promoted from a reviewer probe: RefundLiability.reserve! against a
    # fee-inflated wholesaler allocation.
    test "RefundLiability.reserve! carves liability from a fee-inflated wholesaler share; sums stay exact",
         %{reseller_actor: reseller_actor, reseller: reseller} do
      {wholesaler_actor, wholesaler} = create_dropship_wholesaler!(reseller_actor, reseller)

      drop =
        import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, %{
          "Greater Accra" => 1_500
        })

      # Outstanding refund debt of 700 pesewas owed BY the wholesaler.
      refundable_liability!(reseller, wholesaler, 700)

      assert {:ok, order} =
               Emakola.Orders.CheckoutService.checkout!(
                 reseller.id,
                 [%{variant_id: drop.variant.id, quantity: 1}],
                 region: "greater_accra"
               )

      assert order.total == 6_500

      assert {:split, %{total: total, allocations: allocs}} =
               OrderSettlement.prepare(order.id, reseller.id)

      wholesaler_alloc = find_role(allocs, :wholesaler)
      platform_alloc = find_role(allocs, :platform)
      dropshipper_alloc = find_role(allocs, :dropshipper)

      # Hand-derived: gross share cost 4_000 + fee 1_500 = 5_500; 700 reserved
      # for the refund debt.
      assert wholesaler_alloc.amount == 5_500 - 700
      assert wholesaler_alloc.recovery_amount == 700
      # Platform: margin fee 100 + recovered 700.
      assert platform_alloc.amount == 100 + 700
      # Dropshipper: margin net 900, untouched (no delivery fee this time).
      assert dropshipper_alloc.amount == 900

      assert total == order.total
      assert Enum.sum(Enum.map(allocs, & &1.amount)) == order.total
    end
  end

  # -- Runtime sum-invariant guard -----------------------------------------
  # SplitCalculator's `total` is derived independently of `allocations`
  # (subtotal + dispatch fee values vs. per-supplier grouped allocations), so
  # a dispatch fee keyed to a supplier absent from the line items would
  # inflate `total`/`order.total` without a matching allocation. This guard
  # is the runtime backstop; it's unit-tested directly against hand-built
  # allocations since every real code path's sums are correct by construction.

  describe "sum_matches_total?/2 — runtime sum-invariant guard" do
    test "returns true and does not log when allocations sum to order.total" do
      order = %{id: Ash.UUID.generate(), total: 1_000}
      allocations = [%{amount: 600}, %{amount: 400}]

      log =
        capture_log(fn ->
          assert OrderSettlement.sum_matches_total?(order, allocations)
        end)

      # Async-suite capture_log sees concurrent tests' output; assert only
      # that OUR order id was not logged, not that the world was silent.
      refute log =~ order.id
    end

    test "returns false and logs an error naming the order id and both sums on mismatch" do
      order = %{id: Ash.UUID.generate(), total: 1_000}
      # 600 + 500 = 1_100, not 1_000 — e.g. a dispatch fee for a supplier
      # absent from the order's line items.
      allocations = [%{amount: 600}, %{amount: 500}]

      log =
        capture_log(fn ->
          refute OrderSettlement.sum_matches_total?(order, allocations)
        end)

      assert log =~ order.id
      assert log =~ "1100"
      assert log =~ "1000"
    end
  end

  defp find_role(allocations, role) do
    Enum.find(allocations, &(&1.role == role))
  end

  defp create_dropship_wholesaler!(reseller_actor, reseller) do
    {wholesaler_actor, wholesaler} =
      create_merchant_with_store!(%{
        name: "Fee Split Wholesaler #{System.unique_integer([:positive])}"
      })

    {:ok, connection} =
      Network.request(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        reseller_store_id: reseller.id,
        requested_by_store_id: wholesaler.id
      })

    {:ok, _active} = Network.approve(reseller_actor, connection)
    verified_payout!(wholesaler, "ACCT_#{System.unique_integer([:positive])}")

    {wholesaler_actor, wholesaler}
  end

  defp import_offer!(wholesaler_actor, wholesaler, reseller_actor, reseller, dispatch_fees) do
    product =
      create_product!(wholesaler,
        status: :active,
        title: "Fee Split Item #{System.unique_integer([:positive])}"
      )

    source_variant =
      create_variant!(product, wholesaler,
        price: 6_000,
        sku: "FS-SRC-#{System.unique_integer([:positive])}",
        stock_quantity: 50
      )

    {:ok, offer} =
      Offers.create_draft(wholesaler_actor, %{
        wholesaler_store_id: wholesaler.id,
        source_product_id: product.id,
        earning_model: :markup,
        delivery_areas: Map.keys(dispatch_fees)
      })

    {:ok, _terms} =
      Offers.add_variant(wholesaler_actor, offer, %{
        source_variant_id: source_variant.id,
        supplier_price: 4_000,
        suggested_retail_price: 5_000,
        max_retail_price: 5_800
      })

    {:ok, published} = Offers.publish(wholesaler_actor, offer)

    {:ok, priced} =
      Offers.update_terms(wholesaler_actor, published, %{dispatch_fees: dispatch_fees})

    {:ok, listing} = ListingImporter.import(reseller_actor, reseller.id, priced)

    [variant | _] = listing.reseller_product.variants
    %{variant: variant, supplier_id: listing.supplier_id, offer: priced}
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
