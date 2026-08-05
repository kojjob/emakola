defmodule Emakola.Integration.CheckoutPaymentTest do
  @moduledoc """
  Cross-domain integration tests covering the full purchase lifecycle:
  Catalog -> Orders (checkout) -> Payments, plus edge cases around
  stock, multi-tenancy, order lifecycle, data integrity, and currency.
  """

  use Emakola.DataCase, async: false

  require Ash.Query

  import Emakola.Factory

  alias Emakola.Orders.CheckoutService
  alias Emakola.Payments.Payment
  alias Emakola.Orders.{Order, LineItem}
  alias Emakola.Catalog.Variant

  # ─── Helpers ──────────────────────────────────────────────────────

  defp setup_store_with_product(store_attrs \\ %{}, variant_attrs \\ %{}) do
    store = create_store!(store_attrs)
    product = create_product!(store)

    variant =
      create_variant!(
        product,
        store,
        Map.merge(%{stock_quantity: 10, price: 5000}, variant_attrs)
      )

    customer = create_customer!(store)

    %{store: store, product: product, variant: variant, customer: customer}
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
  # 1. Full Purchase Flow Tests
  # ═══════════════════════════════════════════════════════════════════

  describe "full purchase flow" do
    test "store -> product -> variant -> checkout -> order with correct total -> stock decremented" do
      %{store: store, variant: variant, customer: customer} = setup_store_with_product()

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 2}],
          customer_id: customer.id
        )

      # Order created with correct total
      assert order.store_id == store.id
      assert order.status == :pending
      assert order.total == 10_000
      assert order.subtotal == 10_000

      # Order number generated
      assert order.order_number =~ ~r/^ORD-\d{8}-[A-Z0-9]{6}$/

      # Stock decrements on payment confirmation, not at checkout.
      {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)
      updated_variant = reload_variant(variant)
      assert updated_variant.stock_quantity == 8
    end

    test "checkout with multiple items creates all line items with correct price snapshots" do
      store = create_store!()
      product_a = create_product!(store, %{title: "Widget A"})
      product_b = create_product!(store, %{title: "Widget B"})

      variant_a = create_variant!(product_a, store, %{price: 3000, stock_quantity: 5})
      variant_b = create_variant!(product_b, store, %{price: 7500, stock_quantity: 10})

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [
            %{variant_id: variant_a.id, quantity: 2},
            %{variant_id: variant_b.id, quantity: 3}
          ],
          []
        )

      order = reload_order(order)

      assert length(order.line_items) == 2

      li_a = Enum.find(order.line_items, &(&1.variant_id == variant_a.id))
      li_b = Enum.find(order.line_items, &(&1.variant_id == variant_b.id))

      # Price snapshot correctness
      assert li_a.unit_price == 3000
      assert li_a.quantity == 2
      assert li_a.line_total == 6000
      assert li_a.product_title == "Widget A"

      assert li_b.unit_price == 7500
      assert li_b.quantity == 3
      assert li_b.line_total == 22_500

      # Order total is sum of line totals
      assert order.total == 6000 + 22_500
      assert order.subtotal == order.total

      # Stock decrements on payment confirmation, not at checkout.
      {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)
      assert reload_variant(variant_a).stock_quantity == 3
      assert reload_variant(variant_b).stock_quantity == 7
    end

    test "checkout -> payment success -> order can be confirmed" do
      %{store: store, variant: variant, customer: customer} = setup_store_with_product()

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}],
          customer_id: customer.id
        )

      # Create payment for the order
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: order.total,
          currency: order.currency,
          customer_email: "buyer@example.com"
        })

      assert payment.status == :pending

      # Mark payment as success
      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success", "reference" => "PAY-123"}
        })
        |> Ash.update(authorize?: false)

      assert payment.status == :success

      # Now confirm the order
      {:ok, confirmed_order} =
        order
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update(authorize?: false)

      assert confirmed_order.status == :confirmed
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 2. Payment Edge Cases
  # ═══════════════════════════════════════════════════════════════════

  describe "payment edge cases" do
    test "payment for non-existent order creates payment record with nil order_id" do
      store = create_store!()

      # Payment without an order_id — should succeed
      payment =
        create_payment!(store, %{
          order_id: nil,
          amount: 10_000,
          gateway_reference: "PAY-orphan-#{System.unique_integer([:positive])}"
        })

      assert payment.id
      assert payment.store_id == store.id
      assert is_nil(payment.order_id)
    end

    test "double payment with same gateway_reference is rejected (uniqueness)" do
      store = create_store!()
      ref = "PAY-duplicate-ref-#{System.unique_integer([:positive])}"

      _payment1 = create_payment!(store, %{gateway_reference: ref})

      assert_raise Ash.Error.Invalid, fn ->
        create_payment!(store, %{gateway_reference: ref})
      end
    end

    test "payment amount mismatch with order total is detectable" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{}, %{price: 5000, stock_quantity: 10})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 2}], [])

      assert order.total == 10_000

      # Create payment with mismatched amount
      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: 8000,
          currency: "GHS"
        })

      # The system allows creating the payment but we can detect the mismatch
      reloaded_order = Ash.get!(Order, order.id, authorize?: false)
      assert payment.amount != reloaded_order.total
      assert abs(payment.amount - reloaded_order.total) == 2000
    end

    test "refund exceeding original payment amount is rejected" do
      store = create_store!()

      payment =
        create_payment!(store, %{
          amount: 5000,
          gateway_reference: "PAY-refund-test-#{System.unique_integer([:positive])}"
        })

      # Mark as success first
      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update(authorize?: false)

      # Attempt refund exceeding original amount — must be rejected
      assert {:error, error} =
               payment
               |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 10_000})
               |> Ash.update(authorize?: false)

      assert %Ash.Error.Invalid{} = error

      assert Enum.any?(error.errors, fn e ->
               match?(%Ash.Error.Changes.InvalidAttribute{field: :refunded_amount}, e)
             end)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 3. Stock + Checkout Race Conditions
  # ═══════════════════════════════════════════════════════════════════

  describe "stock and checkout race conditions" do
    test "two concurrent checkouts for the last item both succeed (no reservation)" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{}, %{stock_quantity: 1, price: 5000})

      task1 =
        Task.async(fn ->
          CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])
        end)

      task2 =
        Task.async(fn ->
          CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])
        end)

      results = [Task.await(task1), Task.await(task2)]

      # Checkout reserves no stock — both orders are placed; the oversell is
      # resolved at payment confirmation, not here.
      assert Enum.count(results, &match?({:ok, _}, &1)) == 2
      assert reload_variant(variant).stock_quantity == 1
    end

    test "checkout for item with insufficient stock fails" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{}, %{stock_quantity: 2, price: 5000})

      result =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 5}], [])

      assert {:error, :insufficient_stock} = result

      # Stock unchanged
      assert reload_variant(variant).stock_quantity == 2
    end

    test "large concurrent checkout load: 10 simultaneous checkouts for 5 available items" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{}, %{stock_quantity: 5, price: 1000})

      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])
          end)
        end

      results = Enum.map(tasks, &Task.await(&1, 10_000))

      # No reservation at checkout — all 10 orders are placed; the oversell is
      # resolved at payment confirmation, not here.
      assert Enum.count(results, &match?({:ok, _}, &1)) == 10
      assert reload_variant(variant).stock_quantity == 5
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 4. Multi-Tenant Isolation (Cross-Domain)
  # ═══════════════════════════════════════════════════════════════════

  describe "multi-tenant isolation" do
    setup do
      store_a =
        create_store!(%{name: "Store A", slug: "store-a-#{System.unique_integer([:positive])}"})

      store_b =
        create_store!(%{name: "Store B", slug: "store-b-#{System.unique_integer([:positive])}"})

      product_a = create_product!(store_a, %{title: "Product A"})
      variant_a = create_variant!(product_a, store_a, %{price: 5000, stock_quantity: 10})

      product_b = create_product!(store_b, %{title: "Product B"})
      variant_b = create_variant!(product_b, store_b, %{price: 7000, stock_quantity: 10})

      customer_a = create_customer!(store_a, %{email: "buyer@store-a.com"})
      customer_b = create_customer!(store_b, %{email: "buyer@store-b.com"})

      %{
        store_a: store_a,
        store_b: store_b,
        variant_a: variant_a,
        variant_b: variant_b,
        customer_a: customer_a,
        customer_b: customer_b
      }
    end

    test "store A's customer cannot checkout store B's products", ctx do
      result =
        CheckoutService.checkout!(
          ctx.store_a.id,
          [%{variant_id: ctx.variant_b.id, quantity: 1}],
          customer_id: ctx.customer_a.id
        )

      assert {:error, :variant_not_in_store} = result
    end

    test "store A's order is invisible to store B queries", ctx do
      {:ok, _order_a} =
        CheckoutService.checkout!(
          ctx.store_a.id,
          [%{variant_id: ctx.variant_a.id, quantity: 1}],
          []
        )

      # Query Store B's orders — should be empty
      store_b_orders =
        Order
        |> Ash.Query.filter(store_id == ^ctx.store_b.id)
        |> Ash.read!(authorize?: false)

      assert store_b_orders == []
    end

    test "store A's payment references don't collide with store B's", ctx do
      shared_ref_base = "PAY-shared-#{System.unique_integer([:positive])}"

      _payment_a =
        create_payment!(ctx.store_a, %{
          gateway_reference: "#{shared_ref_base}-A"
        })

      _payment_b =
        create_payment!(ctx.store_b, %{
          gateway_reference: "#{shared_ref_base}-B"
        })

      # Both payments created successfully with different references
      store_a_payments =
        Payment
        |> Ash.Query.filter(store_id == ^ctx.store_a.id)
        |> Ash.read!(authorize?: false)

      store_b_payments =
        Payment
        |> Ash.Query.filter(store_id == ^ctx.store_b.id)
        |> Ash.read!(authorize?: false)

      assert store_a_payments != []
      assert store_b_payments != []

      # No overlap in IDs
      a_ids = MapSet.new(Enum.map(store_a_payments, & &1.id))
      b_ids = MapSet.new(Enum.map(store_b_payments, & &1.id))
      assert MapSet.disjoint?(a_ids, b_ids)
    end

    test "variant from store A cannot be added to store B's order via checkout", ctx do
      # Attempt cross-tenant checkout
      result =
        CheckoutService.checkout!(
          ctx.store_b.id,
          [%{variant_id: ctx.variant_a.id, quantity: 1}],
          []
        )

      assert {:error, :variant_not_in_store} = result

      # Store A stock unchanged
      assert reload_variant(ctx.variant_a).stock_quantity == 10
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 5. Order Lifecycle Edge Cases
  # ═══════════════════════════════════════════════════════════════════

  describe "order lifecycle edge cases" do
    test "cancel a confirmed order succeeds (confirmed -> cancelled is allowed)" do
      %{store: store, variant: variant} = setup_store_with_product()

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      {:ok, confirmed} =
        order
        |> Ash.Changeset.for_update(:confirm, %{})
        |> Ash.update(authorize?: false)

      assert confirmed.status == :confirmed

      {:ok, cancelled} =
        confirmed
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update(authorize?: false)

      assert cancelled.status == :cancelled
    end

    test "confirm a cancelled order fails" do
      %{store: store, variant: variant} = setup_store_with_product()

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      {:ok, cancelled} =
        order
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update(authorize?: false)

      assert cancelled.status == :cancelled

      assert {:error, _} =
               cancelled
               |> Ash.Changeset.for_update(:confirm, %{})
               |> Ash.update(authorize?: false)
    end

    test "cancel an already cancelled order fails (not in [:pending, :confirmed])" do
      %{store: store, variant: variant} = setup_store_with_product()

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      {:ok, cancelled} =
        order
        |> Ash.Changeset.for_update(:cancel, %{})
        |> Ash.update(authorize?: false)

      assert {:error, _} =
               cancelled
               |> Ash.Changeset.for_update(:cancel, %{})
               |> Ash.update(authorize?: false)
    end

    test "checkout with empty cart is rejected" do
      store = create_store!()

      result = CheckoutService.checkout!(store.id, [], [])

      assert {:error, :empty_cart} = result
    end

    test "large order with many line items (20+)" do
      store = create_store!()

      variants =
        for i <- 1..20 do
          product = create_product!(store, %{title: "Item #{i}"})
          create_variant!(product, store, %{price: 1000 * i, stock_quantity: 50})
        end

      items =
        Enum.map(variants, fn v ->
          %{variant_id: v.id, quantity: 2}
        end)

      {:ok, order} = CheckoutService.checkout!(store.id, items, [])

      order = reload_order(order)

      assert length(order.line_items) == 20

      expected_total = Enum.reduce(variants, 0, fn v, acc -> acc + v.price * 2 end)
      assert order.total == expected_total

      # Stock decrements on payment confirmation, not at checkout.
      {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)

      # Verify all stocks decremented
      for v <- variants do
        assert reload_variant(v).stock_quantity == 48
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 6. Data Integrity Tests
  # ═══════════════════════════════════════════════════════════════════

  describe "data integrity" do
    test "deleting a product with existing orders fails due to FK constraint on variants" do
      %{store: store, product: product, variant: variant} = setup_store_with_product()

      # Create an order referencing this variant
      {:ok, _order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      # Attempting to destroy the variant should fail (line_items FK constraint)
      # Ash wraps the Ecto constraint error as Ash.Error.Unknown
      assert_raise Ash.Error.Unknown, fn ->
        variant
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy!(authorize?: false)
      end

      # Attempting to destroy the product should fail (has_many variants)
      # Ash raises Ash.Error.Invalid ("would leave records behind")
      assert_raise Ash.Error.Invalid, fn ->
        product
        |> Ash.Changeset.for_destroy(:destroy)
        |> Ash.destroy!(authorize?: false)
      end
    end

    test "order total matches sum of line_item line_totals" do
      store = create_store!()
      product1 = create_product!(store, %{title: "Alpha"})
      product2 = create_product!(store, %{title: "Beta"})
      product3 = create_product!(store, %{title: "Gamma"})

      v1 = create_variant!(product1, store, %{price: 1500, stock_quantity: 20})
      v2 = create_variant!(product2, store, %{price: 3200, stock_quantity: 20})
      v3 = create_variant!(product3, store, %{price: 750, stock_quantity: 20})

      {:ok, order} =
        CheckoutService.checkout!(
          store.id,
          [
            %{variant_id: v1.id, quantity: 3},
            %{variant_id: v2.id, quantity: 1},
            %{variant_id: v3.id, quantity: 5}
          ],
          []
        )

      order = reload_order(order)

      line_items_sum = Enum.reduce(order.line_items, 0, fn li, acc -> acc + li.line_total end)

      assert order.total == line_items_sum
      assert order.subtotal == line_items_sum

      # Verify each line item individually
      li_v1 = Enum.find(order.line_items, &(&1.variant_id == v1.id))
      assert li_v1.line_total == 1500 * 3

      li_v2 = Enum.find(order.line_items, &(&1.variant_id == v2.id))
      assert li_v2.line_total == 3200

      li_v3 = Enum.find(order.line_items, &(&1.variant_id == v3.id))
      assert li_v3.line_total == 750 * 5
    end

    test "line item unit_price snapshots variant price at time of creation" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{}, %{price: 8000, stock_quantity: 10})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      order = reload_order(order)
      line_item = hd(order.line_items)

      assert line_item.unit_price == 8000

      # Now change the variant price
      {:ok, _updated_variant} =
        variant
        |> Ash.Changeset.for_update(:update, %{price: 12_000})
        |> Ash.update(authorize?: false)

      # Reload the line item — the snapshot should NOT change
      reloaded_li = Ash.get!(LineItem, line_item.id, authorize?: false)
      assert reloaded_li.unit_price == 8000
    end

    test "line item product_title snapshots product title at creation" do
      store = create_store!()
      product = create_product!(store, %{title: "Original Title"})
      variant = create_variant!(product, store, %{price: 5000, stock_quantity: 5})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      order = reload_order(order)
      line_item = hd(order.line_items)
      assert line_item.product_title == "Original Title"

      # Update product title
      {:ok, _} =
        product
        |> Ash.Changeset.for_update(:update, %{title: "Updated Title"})
        |> Ash.update(authorize?: false)

      # Line item snapshot unchanged
      reloaded_li = Ash.get!(LineItem, line_item.id, authorize?: false)
      assert reloaded_li.product_title == "Original Title"
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 7. Currency Consistency Tests
  # ═══════════════════════════════════════════════════════════════════

  describe "currency consistency" do
    test "order uses GHS currency from store by default" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{currency: "GHS"})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      assert order.currency == "GHS"
    end

    test "all monetary fields in order and line items are integers (no floats)" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{}, %{price: 12_345, stock_quantity: 10})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 3}], [])

      order = reload_order(order)

      # Order amounts are integers
      assert is_integer(order.total)
      assert is_integer(order.subtotal)

      # Line item amounts are integers
      for li <- order.line_items do
        assert is_integer(li.unit_price)
        assert is_integer(li.line_total)
        assert is_integer(li.quantity)
      end

      # Variant price is an integer
      assert is_integer(reload_variant(variant).price)
    end

    test "payment currency matches order currency" do
      %{store: store, variant: variant} =
        setup_store_with_product(%{currency: "GHS"})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

      payment =
        create_payment!(store, %{
          order_id: order.id,
          amount: order.total,
          currency: order.currency
        })

      assert payment.currency == order.currency
      assert payment.currency == "GHS"
      assert payment.amount == order.total
    end

    test "NGN store keeps amounts in kobo (integer minor units)" do
      store = create_store!(%{currency: "NGN"})
      product = create_product!(store, %{title: "Jollof Rice"})
      variant = create_variant!(product, store, %{price: 250_000, stock_quantity: 5})

      {:ok, order} =
        CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 2}], [])

      assert order.total == 500_000
      assert is_integer(order.total)

      order = reload_order(order)
      li = hd(order.line_items)
      assert li.unit_price == 250_000
      assert li.line_total == 500_000
      assert is_integer(li.unit_price)
    end
  end
end
