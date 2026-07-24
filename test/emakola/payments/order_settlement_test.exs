defmodule Emakola.Payments.OrderSettlementTest do
  @moduledoc """
  Order-aware glue for SP5: loads a placed order's line items, asks
  DropshipSettlement for a split, exposes gateway shares for payment
  initiation, and persists the resulting PaymentSplit records.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory

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
