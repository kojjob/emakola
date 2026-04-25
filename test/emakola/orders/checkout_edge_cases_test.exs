defmodule Emakola.Orders.CheckoutEdgeCasesTest do
  @moduledoc """
  Edge case tests for the CheckoutService.

  Covers cross-store variant checkout, out-of-stock, deleted variants,
  zero/negative quantities, concurrent stock depletion, delivery fee
  edge cases, and price snapshot integrity.
  """

  use Emakola.DataCase, async: false

  require Ash.Query

  import Emakola.Factory

  alias Emakola.Orders.CheckoutService
  alias Emakola.Orders.{Order, LineItem}
  alias Emakola.Catalog.Variant

  # ── Helpers ──────────────────────────────────────────────────────

  defp setup_store_with_variant(store_attrs \\ %{}, variant_attrs \\ %{}) do
    store = create_store!(store_attrs)
    product = create_product!(store)

    variant =
      create_variant!(
        product,
        store,
        Map.merge(%{stock_quantity: 10, price: 5000}, variant_attrs)
      )

    %{store: store, product: product, variant: variant}
  end

  defp reload_variant(variant) do
    Ash.get!(Variant, variant.id, authorize?: false)
  end

  defp reload_order(order) do
    order.id
    |> then(&Ash.get!(Order, &1, authorize?: false))
    |> Ash.load!(:line_items, authorize?: false)
  end

  # ═══════════════════════════════════════════════════════════════════
  # 1. Checkout With Variant From Different Store
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with variant from different store" do
    test "attempting to checkout store B's variant under store A fails" do
      ctx_a =
        setup_store_with_variant(%{
          name: "Store Alpha",
          slug: "store-alpha-#{System.unique_integer([:positive])}"
        })

      ctx_b =
        setup_store_with_variant(%{
          name: "Store Beta",
          slug: "store-beta-#{System.unique_integer([:positive])}"
        })

      result =
        CheckoutService.checkout!(
          ctx_a.store.id,
          [%{variant_id: ctx_b.variant.id, quantity: 1}],
          []
        )

      assert {:error, :variant_not_in_store} = result

      # Stock of store B's variant should be unchanged
      assert reload_variant(ctx_b.variant).stock_quantity == 10
    end

    test "mixing variants from two different stores fails" do
      ctx_a =
        setup_store_with_variant(%{
          name: "Mix Store A",
          slug: "mix-a-#{System.unique_integer([:positive])}"
        })

      ctx_b =
        setup_store_with_variant(%{
          name: "Mix Store B",
          slug: "mix-b-#{System.unique_integer([:positive])}"
        })

      result =
        CheckoutService.checkout!(
          ctx_a.store.id,
          [
            %{variant_id: ctx_a.variant.id, quantity: 1},
            %{variant_id: ctx_b.variant.id, quantity: 1}
          ],
          []
        )

      assert {:error, :variant_not_in_store} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 2. Checkout With Out-of-Stock Variant
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with out-of-stock variant" do
    test "checkout with zero stock fails with clear error" do
      ctx = setup_store_with_variant(%{}, %{stock_quantity: 0})

      result =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          []
        )

      assert {:error, :insufficient_stock} = result
    end

    test "checkout requesting more than available stock fails" do
      ctx = setup_store_with_variant(%{}, %{stock_quantity: 3})

      result =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 5}],
          []
        )

      assert {:error, :insufficient_stock} = result

      # Stock unchanged
      assert reload_variant(ctx.variant).stock_quantity == 3
    end

    test "checkout requesting exactly available stock succeeds" do
      ctx = setup_store_with_variant(%{}, %{stock_quantity: 3})

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 3}],
          []
        )

      assert order.total == 5000 * 3
      assert reload_variant(ctx.variant).stock_quantity == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 3. Checkout With Variant Deleted Mid-Checkout
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with variant that was deleted" do
    test "checkout with non-existent variant_id fails" do
      store = create_store!()
      fake_variant_id = Ash.UUID.generate()

      result =
        CheckoutService.checkout!(
          store.id,
          [%{variant_id: fake_variant_id, quantity: 1}],
          []
        )

      assert {:error, :variant_not_found} = result
    end

    test "checkout with one valid and one non-existent variant fails entirely" do
      ctx = setup_store_with_variant()
      fake_variant_id = Ash.UUID.generate()

      result =
        CheckoutService.checkout!(
          ctx.store.id,
          [
            %{variant_id: ctx.variant.id, quantity: 1},
            %{variant_id: fake_variant_id, quantity: 1}
          ],
          []
        )

      assert {:error, :variant_not_found} = result

      # Stock of the valid variant should be unchanged (transaction rolled back)
      assert reload_variant(ctx.variant).stock_quantity == 10
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 4. Checkout With Zero Quantity
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with zero quantity" do
    test "line item with quantity 0 is rejected by validation" do
      ctx = setup_store_with_variant()

      # The LineItem resource validates quantity > 0.
      # The checkout service creates line items inside a transaction,
      # so a quantity of 0 should cause the transaction to fail.
      result =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 0}],
          []
        )

      # The Ash validation on LineItem rejects quantity <= 0
      assert {:error, _} = result
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 5. Checkout With Negative Quantity
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with negative quantity" do
    test "line item with negative quantity is rejected" do
      ctx = setup_store_with_variant()

      result =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: -1}],
          []
        )

      assert {:error, _} = result

      # Stock unchanged
      assert reload_variant(ctx.variant).stock_quantity == 10
    end

    test "negative quantity does not increase stock" do
      ctx = setup_store_with_variant(%{}, %{stock_quantity: 5})

      result =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: -3}],
          []
        )

      assert {:error, _} = result

      # Stock must remain exactly 5 — never increased
      assert reload_variant(ctx.variant).stock_quantity == 5
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 6. Concurrent Checkouts Depleting Same Stock
  # ═══════════════════════════════════════════════════════════════════

  describe "concurrent checkouts depleting same stock" do
    test "exactly N succeed when N items available and N+M concurrent checkouts" do
      # 5 items in stock, 10 concurrent checkout attempts for 1 each
      ctx = setup_store_with_variant(%{}, %{stock_quantity: 5, price: 1000})

      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            CheckoutService.checkout!(
              ctx.store.id,
              [%{variant_id: ctx.variant.id, quantity: 1}],
              []
            )
          end)
        end

      results = Enum.map(tasks, &Task.await(&1, 15_000))
      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, _}, &1))

      assert successes == 5,
             "Expected 5 successes, got #{successes}. Results: #{inspect(results)}"

      assert failures == 5,
             "Expected 5 failures, got #{failures}. Results: #{inspect(results)}"

      # Final stock must be exactly 0
      assert reload_variant(ctx.variant).stock_quantity == 0
    end

    test "concurrent checkouts for quantity > 1 respect stock limits" do
      # 10 items in stock, 5 concurrent checkout attempts for 3 each
      # Only 3 can succeed (3*3 = 9 <= 10, but 4th would need 12 > 10)
      ctx = setup_store_with_variant(%{}, %{stock_quantity: 10, price: 2000})

      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            CheckoutService.checkout!(
              ctx.store.id,
              [%{variant_id: ctx.variant.id, quantity: 3}],
              []
            )
          end)
        end

      results = Enum.map(tasks, &Task.await(&1, 15_000))
      successes = Enum.count(results, &match?({:ok, _}, &1))

      # At most 3 can succeed (3*3=9, 4th would need 12 total)
      assert successes == 3,
             "Expected 3 successes, got #{successes}. Results: #{inspect(results)}"

      final_stock = reload_variant(ctx.variant).stock_quantity
      assert final_stock == 1, "Expected 1 remaining stock, got #{final_stock}"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 7. Delivery Fee Edge Cases
  # ═══════════════════════════════════════════════════════════════════

  describe "delivery fee edge cases" do
    test "checkout with delivery_fee: 0 results in total == subtotal" do
      ctx = setup_store_with_variant()

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 2}],
          delivery_fee: 0
        )

      assert order.subtotal == 10_000
      assert order.total == 10_000
      assert order.total == order.subtotal
    end

    test "checkout with positive delivery_fee adds to total" do
      ctx = setup_store_with_variant()

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 2}],
          delivery_fee: 1500
        )

      assert order.subtotal == 10_000
      assert order.total == 11_500
      assert order.total == order.subtotal + 1500
    end

    test "checkout without delivery_fee defaults to 0" do
      ctx = setup_store_with_variant()

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          []
        )

      assert order.total == order.subtotal
      assert order.total == 5000
    end

    test "checkout with negative delivery_fee still calculates (application should validate upstream)" do
      ctx = setup_store_with_variant()

      # The CheckoutService uses Keyword.get(opts, :delivery_fee, 0)
      # and adds it to subtotal. A negative fee reduces the total.
      # This is an edge case — upstream validation should prevent it.
      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 2}],
          delivery_fee: -500
        )

      # Subtotal is item total, total includes delivery
      assert order.subtotal == 10_000
      assert order.total == 9500
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 8. Price Snapshot Integrity
  # ═══════════════════════════════════════════════════════════════════

  describe "price snapshot integrity" do
    test "line_item.unit_price matches variant.price at checkout time" do
      ctx = setup_store_with_variant(%{}, %{price: 7500})

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 3}],
          []
        )

      order = reload_order(order)
      line_item = hd(order.line_items)

      assert line_item.unit_price == 7500
      assert line_item.quantity == 3
      assert line_item.line_total == 7500 * 3
    end

    test "price change after checkout does not affect existing line items" do
      ctx = setup_store_with_variant(%{}, %{price: 8000, stock_quantity: 20})

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 2}],
          []
        )

      order = reload_order(order)
      original_li = hd(order.line_items)
      assert original_li.unit_price == 8000

      # Change variant price
      {:ok, _updated_variant} =
        ctx.variant
        |> Ash.Changeset.for_update(:update, %{price: 12_000})
        |> Ash.update(authorize?: false)

      # Verify snapshot is preserved
      reloaded_li = Ash.get!(LineItem, original_li.id, authorize?: false, authorize?: false)
      assert reloaded_li.unit_price == 8000
      assert reloaded_li.line_total == 16_000
    end

    test "product title snapshot is preserved after product title change" do
      store = create_store!()
      product = create_product!(store, %{title: "Original Kente"})
      variant = create_variant!(product, store, %{price: 5000, stock_quantity: 10})

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      order = reload_order(order)
      li = hd(order.line_items)
      assert li.product_title == "Original Kente"

      # Rename product
      {:ok, _} =
        product
        |> Ash.Changeset.for_update(:update, %{title: "New Kente Design"})
        |> Ash.update(authorize?: false)

      # Snapshot unchanged
      reloaded_li = Ash.get!(LineItem, li.id, authorize?: false, authorize?: false)
      assert reloaded_li.product_title == "Original Kente"
    end

    test "variant SKU is snapshotted at checkout time" do
      store = create_store!()
      product = create_product!(store)

      variant =
        create_variant!(product, store, %{price: 3000, stock_quantity: 10, sku: "KNT-001"})

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 1}],
          []
        )

      order = reload_order(order)
      li = hd(order.line_items)
      assert li.variant_sku == "KNT-001"

      # Change SKU
      {:ok, _} =
        variant
        |> Ash.Changeset.for_update(:update, %{sku: "KNT-002"})
        |> Ash.update(authorize?: false)

      reloaded_li = Ash.get!(LineItem, li.id, authorize?: false, authorize?: false)
      assert reloaded_li.variant_sku == "KNT-001"
    end

    test "multi-item checkout snapshots correct prices for each variant" do
      store = create_store!()
      product_a = create_product!(store, %{title: "Ankara Fabric"})
      product_b = create_product!(store, %{title: "Kente Cloth"})

      variant_a = create_variant!(product_a, store, %{price: 3000, stock_quantity: 20})
      variant_b = create_variant!(product_b, store, %{price: 8500, stock_quantity: 20})

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [
            %{variant_id: variant_a.id, quantity: 4},
            %{variant_id: variant_b.id, quantity: 2}
          ],
          []
        )

      order = reload_order(order)
      assert length(order.line_items) == 2

      li_a = Enum.find(order.line_items, &(&1.variant_id == variant_a.id))
      li_b = Enum.find(order.line_items, &(&1.variant_id == variant_b.id))

      assert li_a.unit_price == 3000
      assert li_a.quantity == 4
      assert li_a.line_total == 12_000
      assert li_a.product_title == "Ankara Fabric"

      assert li_b.unit_price == 8500
      assert li_b.quantity == 2
      assert li_b.line_total == 17_000
      assert li_b.product_title == "Kente Cloth"

      assert order.total == 12_000 + 17_000
      assert order.subtotal == order.total
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 9. Checkout With Shipping/Billing Address
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with address options" do
    test "shipping and billing addresses are stored on the order" do
      ctx = setup_store_with_variant()

      shipping = %{
        "street" => "23 Oxford Street",
        "city" => "Osu, Accra",
        "region" => "Greater Accra",
        "country" => "GH"
      }

      billing = %{
        "street" => "45 Independence Ave",
        "city" => "Ridge, Accra",
        "region" => "Greater Accra",
        "country" => "GH"
      }

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          shipping_address: shipping,
          billing_address: billing
        )

      assert order.shipping_address == shipping
      assert order.billing_address == billing
    end

    test "checkout without addresses defaults to nil" do
      ctx = setup_store_with_variant()

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          []
        )

      assert is_nil(order.shipping_address)
      assert is_nil(order.billing_address)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 10. Checkout With Customer Association
  # ═══════════════════════════════════════════════════════════════════

  describe "checkout with customer association" do
    test "order is associated with the given customer" do
      ctx = setup_store_with_variant()
      customer = create_customer!(ctx.store)

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          customer_id: customer.id
        )

      assert order.customer_id == customer.id
    end

    test "order without customer_id has nil customer association" do
      ctx = setup_store_with_variant()

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          []
        )

      assert is_nil(order.customer_id)
    end
  end
end
