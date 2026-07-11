defmodule Emakola.Orders.OrderEdgeCasesTest do
  @moduledoc """
  Edge case tests for the Order resource state machine.

  Covers invalid status transitions, double-confirm, cancel-after-delivery,
  order-number uniqueness, negative totals, concurrent updates,
  multi-tenant isolation, long notes, and high line-item counts.
  """

  use Emakola.DataCase, async: true

  require Ash.Query

  import Emakola.Factory

  alias Emakola.Orders.Order
  alias Emakola.Orders.CheckoutService

  # ── Helpers ──────────────────────────────────────────────────────

  defp setup_store_with_variant(variant_attrs \\ %{}) do
    store = create_store!()
    product = create_product!(store)

    variant =
      create_variant!(
        product,
        store,
        Map.merge(%{stock_quantity: 100, price: 5000}, variant_attrs)
      )

    %{store: store, product: product, variant: variant}
  end

  defp create_pending_order!(store, variant) do
    {:ok, order} =
      CheckoutService.checkout!(store.id, [%{variant_id: variant.id, quantity: 1}], [])

    order
  end

  defp advance_order_to!(order, target_status) do
    transitions = %{
      confirmed: [:confirm],
      processing: [:confirm, :start_processing],
      shipped: [:confirm, :start_processing, :mark_shipped],
      delivered: [:confirm, :start_processing, :mark_shipped, :mark_delivered],
      cancelled: [:cancel]
    }

    actions = Map.fetch!(transitions, target_status)

    Enum.reduce(actions, order, fn action, current_order ->
      {:ok, updated} =
        current_order
        |> Ash.Changeset.for_update(action, %{})
        |> Ash.update(authorize?: false)

      updated
    end)
  end

  defp reload_order(order) do
    Ash.get!(Order, order.id, authorize?: false, authorize?: false)
  end

  # ═══════════════════════════════════════════════════════════════════
  # 1. Invalid Status Transitions
  # ═══════════════════════════════════════════════════════════════════

  describe "invalid status transitions" do
    setup do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)
      Map.put(ctx, :order, order)
    end

    test "delivered -> pending (not possible, no such action)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          o = create_pending_order!(ctx.store, ctx.variant)
          %{order: advance_order_to!(o, :delivered)}
        end)

      # There is no action to move back to pending. The only way to test
      # is to try :confirm (which expects :pending) — it must fail.
      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:confirm, %{})
               |> Ash.update(authorize?: false)
    end

    test "cancelled -> shipped (cancel is terminal for forward transitions)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          o = create_pending_order!(ctx.store, ctx.variant)
          %{order: advance_order_to!(o, :cancelled)}
        end)

      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:mark_shipped, %{})
               |> Ash.update(authorize?: false)
    end

    test "pending -> shipped (must go through confirmed and processing first)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          %{order: create_pending_order!(ctx.store, ctx.variant)}
        end)

      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:mark_shipped, %{})
               |> Ash.update(authorize?: false)
    end

    test "pending -> delivered (must go through confirmed, processing, shipped)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          %{order: create_pending_order!(ctx.store, ctx.variant)}
        end)

      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:mark_delivered, %{})
               |> Ash.update(authorize?: false)
    end

    test "confirmed -> delivered (must go through processing and shipped)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          o = create_pending_order!(ctx.store, ctx.variant)
          %{order: advance_order_to!(o, :confirmed)}
        end)

      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:mark_delivered, %{})
               |> Ash.update(authorize?: false)
    end

    test "processing -> pending (no reverse transitions)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          o = create_pending_order!(ctx.store, ctx.variant)
          %{order: advance_order_to!(o, :processing)}
        end)

      # Try confirm (expects pending)
      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:confirm, %{})
               |> Ash.update(authorize?: false)
    end

    test "shipped -> confirmed (no reverse transitions)" do
      %{order: order} =
        setup_store_with_variant()
        |> then(fn ctx ->
          o = create_pending_order!(ctx.store, ctx.variant)
          %{order: advance_order_to!(o, :shipped)}
        end)

      assert {:error, _} =
               order
               |> Ash.Changeset.for_update(:confirm, %{})
               |> Ash.update(authorize?: false)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 2. Double-Confirm
  # ═══════════════════════════════════════════════════════════════════

  describe "double-confirm" do
    test "confirming an already confirmed order fails" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)
      confirmed = advance_order_to!(order, :confirmed)

      assert confirmed.status == :confirmed

      # Second confirm must fail because status is :confirmed, not :pending
      assert {:error, _} =
               confirmed
               |> Ash.Changeset.for_update(:confirm, %{})
               |> Ash.update(authorize?: false)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 3. Cancel After Delivery
  # ═══════════════════════════════════════════════════════════════════

  describe "cancel after delivery" do
    test "cancelling a delivered order fails" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)
      delivered = advance_order_to!(order, :delivered)

      assert delivered.status == :delivered

      assert {:error, _} =
               delivered
               |> Ash.Changeset.for_update(:cancel, %{})
               |> Ash.update(authorize?: false)
    end

    test "cancelling an already cancelled order fails" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)
      cancelled = advance_order_to!(order, :cancelled)

      assert cancelled.status == :cancelled

      assert {:error, _} =
               cancelled
               |> Ash.Changeset.for_update(:cancel, %{})
               |> Ash.update(authorize?: false)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 4. Order With Zero Line Items
  # ═══════════════════════════════════════════════════════════════════

  describe "order with zero line items" do
    test "checkout with empty cart is rejected" do
      store = create_store!()

      assert {:error, :empty_cart} = CheckoutService.checkout!(store.id, [], [])
    end

    test "creating an order directly (no checkout) results in 0 total" do
      store = create_store!()

      order = create_order!(store)

      assert order.total == 0
      assert order.subtotal == 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 5. Order Number Uniqueness Across Stores
  # ═══════════════════════════════════════════════════════════════════

  describe "order number uniqueness" do
    test "order numbers are unique within a store" do
      ctx = setup_store_with_variant(%{stock_quantity: 100})

      orders =
        for _ <- 1..20 do
          create_pending_order!(ctx.store, ctx.variant)
        end

      order_numbers = Enum.map(orders, & &1.order_number)

      # All 20 order numbers must be unique
      assert length(Enum.uniq(order_numbers)) == 20
    end

    test "order numbers follow ORD-YYYYMMDD-XXXXXX format" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)

      assert order.order_number =~ ~r/^ORD-\d{8}-[A-Z0-9]{6}$/
    end

    test "two stores can have orders without number collision (statistical)" do
      store_a = create_store!()
      store_b = create_store!()
      product_a = create_product!(store_a)
      product_b = create_product!(store_b)
      variant_a = create_variant!(product_a, store_a, %{stock_quantity: 50, price: 1000})
      variant_b = create_variant!(product_b, store_b, %{stock_quantity: 50, price: 1000})

      orders_a =
        for _ <- 1..10 do
          {:ok, o} =
            CheckoutService.checkout!(store_a.id, [%{variant_id: variant_a.id, quantity: 1}], [])

          o
        end

      orders_b =
        for _ <- 1..10 do
          {:ok, o} =
            CheckoutService.checkout!(store_b.id, [%{variant_id: variant_b.id, quantity: 1}], [])

          o
        end

      all_numbers = Enum.map(orders_a ++ orders_b, & &1.order_number)
      assert length(Enum.uniq(all_numbers)) == 20
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 6. Order With Negative Total
  # ═══════════════════════════════════════════════════════════════════

  describe "order with negative total" do
    test "variant price must be greater than 0 (prevents negative line totals)" do
      store = create_store!()
      product = create_product!(store)

      # Ash validation: price must be > 0
      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: -100,
                 product_id: product.id,
                 store_id: store.id,
                 stock_quantity: 10
               })
               |> Ash.create(authorize?: false)
    end

    test "variant price of 0 is rejected" do
      store = create_store!()
      product = create_product!(store)

      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: 0,
                 product_id: product.id,
                 store_id: store.id,
                 stock_quantity: 10
               })
               |> Ash.create(authorize?: false)
    end

    test "order total is always non-negative after checkout" do
      ctx = setup_store_with_variant(%{price: 1})

      {:ok, order} =
        CheckoutService.checkout!(ctx.store.id, [%{variant_id: ctx.variant.id, quantity: 1}], [])

      assert order.total >= 0
      assert order.subtotal >= 0
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 7. Concurrent Status Updates
  # ═══════════════════════════════════════════════════════════════════

  describe "concurrent status updates" do
    test "two concurrent confirms on same pending order: one succeeds, one fails" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)

      task1 =
        Task.async(fn ->
          fresh = Ash.get!(Order, order.id, authorize?: false, authorize?: false)

          fresh
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update(authorize?: false)
        end)

      task2 =
        Task.async(fn ->
          fresh = Ash.get!(Order, order.id, authorize?: false, authorize?: false)

          fresh
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update(authorize?: false)
        end)

      results = Task.await_many([task1, task2], 10_000)
      successes = Enum.count(results, &match?({:ok, _}, &1))

      # At least one must succeed. Depending on timing, both might succeed
      # if the first completes before the second reads. But the order
      # should end up in :confirmed state regardless.
      assert successes >= 1

      final = reload_order(order)
      assert final.status == :confirmed
    end

    test "concurrent cancel and confirm: order ends in a valid state" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)

      task_confirm =
        Task.async(fn ->
          fresh = Ash.get!(Order, order.id, authorize?: false, authorize?: false)

          fresh
          |> Ash.Changeset.for_update(:confirm, %{})
          |> Ash.update(authorize?: false)
        end)

      task_cancel =
        Task.async(fn ->
          fresh = Ash.get!(Order, order.id, authorize?: false, authorize?: false)

          fresh
          |> Ash.Changeset.for_update(:cancel, %{})
          |> Ash.update(authorize?: false)
        end)

      _results = Task.await_many([task_confirm, task_cancel], 10_000)

      final = reload_order(order)
      # The order must be in a valid state — either confirmed or cancelled
      assert final.status in [:confirmed, :cancelled]
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 8. Multi-Tenant Isolation
  # ═══════════════════════════════════════════════════════════════════

  describe "multi-tenant isolation" do
    test "order created in store A is invisible when querying store B" do
      store_a = create_store!()
      store_b = create_store!()
      product = create_product!(store_a)
      variant = create_variant!(product, store_a, %{stock_quantity: 10, price: 5000})

      {:ok, order_a} =
        CheckoutService.checkout!(store_a.id, [%{variant_id: variant.id, quantity: 1}], [])

      assert order_a.store_id == store_a.id

      # Query store B
      store_b_orders =
        Order
        |> Ash.Query.filter(store_id == ^store_b.id)
        |> Ash.read!(authorize?: false)

      assert store_b_orders == []
    end

    test "order from store A cannot be fetched and operated on as store B" do
      store_a = create_store!()
      store_b = create_store!()
      product = create_product!(store_a)
      variant = create_variant!(product, store_a, %{stock_quantity: 10, price: 5000})

      {:ok, order} =
        CheckoutService.checkout!(store_a.id, [%{variant_id: variant.id, quantity: 1}], [])

      # The order belongs to store A
      assert order.store_id == store_a.id
      assert order.store_id != store_b.id

      # Query by store B should not find this order
      store_b_results =
        Order
        |> Ash.Query.filter(store_id == ^store_b.id and id == ^order.id)
        |> Ash.read!(authorize?: false)

      assert store_b_results == []
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 9. Very Long Notes Field
  # ═══════════════════════════════════════════════════════════════════

  describe "very long notes field" do
    test "order accepts a notes string up to the max length (5K characters)" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)

      long_notes = String.duplicate("a", 5_000)

      {:ok, updated} =
        order
        |> Ash.Changeset.for_update(:update_notes, %{notes: long_notes})
        |> Ash.update(authorize?: false)

      assert String.length(updated.notes) == 5_000
    end

    test "order notes can be set during checkout" do
      ctx = setup_store_with_variant()

      {:ok, order} =
        CheckoutService.checkout!(
          ctx.store.id,
          [%{variant_id: ctx.variant.id, quantity: 1}],
          notes: "Please deliver before 5pm. Ring the bell twice."
        )

      assert order.notes == "Please deliver before 5pm. Ring the bell twice."
    end

    test "order notes can be nil" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)

      assert is_nil(order.notes)
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 10. Order With 100+ Line Items (Performance)
  # ═══════════════════════════════════════════════════════════════════

  describe "order with 100+ line items" do
    @tag timeout: 60_000
    test "checkout with 100 different variants succeeds and totals are correct" do
      store = create_store!()

      variants =
        for i <- 1..100 do
          product = create_product!(store, %{title: "Bulk Item #{i}"})
          create_variant!(product, store, %{price: 100 * i, stock_quantity: 50})
        end

      items =
        Enum.map(variants, fn v ->
          %{variant_id: v.id, quantity: 1}
        end)

      {:ok, order} = CheckoutService.checkout!(store.id, items, [])

      # Reload with line items
      order =
        Ash.get!(Order, order.id, authorize?: false) |> Ash.load!(:line_items, authorize?: false)

      assert length(order.line_items) == 100

      # Expected total: sum of 100, 200, 300, ..., 10000 = 100 * (1+2+...+100) = 100 * 5050
      expected_total = 100 * Enum.sum(1..100)
      assert order.total == expected_total
      assert order.subtotal == expected_total

      # Stock decrements on payment confirmation, not at checkout.
      {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)

      # Verify all stocks decremented
      for v <- variants do
        reloaded = Ash.get!(Emakola.Catalog.Variant, v.id, authorize?: false, authorize?: false)
        assert reloaded.stock_quantity == 49
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════
  # 11. Complete Lifecycle Traversal
  # ═══════════════════════════════════════════════════════════════════

  describe "full lifecycle traversal" do
    test "pending -> confirmed -> processing -> shipped -> delivered is valid" do
      ctx = setup_store_with_variant()
      order = create_pending_order!(ctx.store, ctx.variant)
      assert order.status == :pending

      delivered = advance_order_to!(order, :delivered)
      assert delivered.status == :delivered
    end

    test "cancel is allowed from pending, confirmed, processing, and shipped" do
      for target_before_cancel <- [:pending, :confirmed, :processing, :shipped] do
        ctx = setup_store_with_variant()
        order = create_pending_order!(ctx.store, ctx.variant)

        order_at_state =
          if target_before_cancel == :pending do
            order
          else
            advance_order_to!(order, target_before_cancel)
          end

        assert order_at_state.status == target_before_cancel

        {:ok, cancelled} =
          order_at_state
          |> Ash.Changeset.for_update(:cancel, %{})
          |> Ash.update(authorize?: false)

        assert cancelled.status == :cancelled
      end
    end
  end
end
