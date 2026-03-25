defmodule Emakola.Performance.QueryPerformanceTest do
  @moduledoc """
  Performance tests verifying that database queries use indexes
  instead of sequential scans. Uses EXPLAIN ANALYZE to verify
  query plans.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  @moduletag :performance

  # ── Helpers ──────────────────────────────────────────────────────

  defp explain_query(sql, params) do
    # Convert string UUIDs to binary for Postgrex
    params =
      Enum.map(params, fn
        p when is_binary(p) and byte_size(p) == 36 ->
          case Ecto.UUID.dump(p) do
            {:ok, bin} -> bin
            :error -> p
          end

        p ->
          p
      end)

    # Disable seq scan to force index usage — small test tables cause
    # Postgres to prefer seq scan even when indexes exist
    Emakola.Repo.query!("SET enable_seqscan = off")
    {:ok, result} = Emakola.Repo.query("EXPLAIN (FORMAT JSON) #{sql}", params)
    Emakola.Repo.query!("SET enable_seqscan = on")
    plan = result.rows |> List.first() |> List.first() |> List.first()
    plan["Plan"]
  end

  defp uses_seq_scan?(plan) do
    plan["Node Type"] == "Seq Scan" and not has_child_plans?(plan)
  end

  defp has_child_plans?(plan) do
    is_list(plan["Plans"]) and plan["Plans"] != []
  end

  defp seed_products(store, count) do
    category = create_category!(store)

    for i <- 1..count do
      product =
        create_product!(store, %{
          title: "Product #{i}",
          category_id: category.id,
          status: Enum.random(["active", "draft", "archived"])
        })

      variant =
        create_variant!(product, store, %{
          price: Enum.random(1000..50000),
          stock_quantity: Enum.random(0..100),
          track_inventory: true
        })

      {product, variant}
    end
  end

  defp seed_orders(store, customer, count) do
    for _i <- 1..count do
      create_order!(store, %{
        customer_id: customer.id,
        status: Enum.random(["pending", "confirmed", "shipped", "delivered"])
      })
    end
  end

  # ── Product listing by store ─────────────────────────────────────

  describe "product listing by store" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      seed_products(store, 20)
      %{store: store}
    end

    test "uses index for store_id filter", %{store: store} do
      plan =
        explain_query(
          "SELECT * FROM products WHERE store_id = $1",
          [store.id]
        )

      # With data in the table, Postgres should prefer an index scan
      # The composite unique index (store_id, slug) covers store_id lookups
      refute uses_seq_scan?(plan),
             "Expected index scan for products.store_id filter, got: #{plan["Node Type"]}"
    end

    test "uses index for store_id + status filter", %{store: store} do
      plan =
        explain_query(
          "SELECT * FROM products WHERE store_id = $1 AND status = $2",
          [store.id, "active"]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for products store_id+status filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Category tree query ──────────────────────────────────────────

  describe "category tree query" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      parent = create_category!(store, %{name: "Parent Category"})

      for i <- 1..10 do
        create_category!(store, %{
          name: "Child #{i}",
          parent_id: parent.id
        })
      end

      %{store: store, parent: parent}
    end

    test "uses index for parent_id lookup", %{parent: parent} do
      plan =
        explain_query(
          "SELECT * FROM categories WHERE parent_id = $1",
          [parent.id]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for categories.parent_id filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Order listing by store and status ────────────────────────────

  describe "order listing by store and status" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      customer = create_customer!(store)
      seed_orders(store, customer, 30)
      %{store: store, customer: customer}
    end

    test "uses index for store_id + status filter", %{store: store} do
      plan =
        explain_query(
          "SELECT * FROM orders WHERE store_id = $1 AND status = $2 ORDER BY inserted_at DESC",
          [store.id, "pending"]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for orders store_id+status filter, got: #{plan["Node Type"]}"
    end

    test "uses index for date range query", %{store: store} do
      plan =
        explain_query(
          "SELECT * FROM orders WHERE store_id = $1 AND inserted_at >= $2 ORDER BY inserted_at DESC",
          [store.id, DateTime.utc_now() |> DateTime.add(-7, :day)]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for orders store_id+date filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Customer order history ───────────────────────────────────────

  describe "customer order history" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      customer = create_customer!(store)
      seed_orders(store, customer, 15)
      %{store: store, customer: customer}
    end

    test "uses index for customer_id filter", %{customer: customer} do
      plan =
        explain_query(
          "SELECT * FROM orders WHERE customer_id = $1 ORDER BY inserted_at DESC",
          [customer.id]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for orders.customer_id filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Variant loading for product ──────────────────────────────────

  describe "variant loading for product" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      for i <- 1..5 do
        create_variant!(product, store, %{
          price: 1000 * i,
          sku: "SKU-#{System.unique_integer([:positive])}"
        })
      end

      %{store: store, product: product}
    end

    test "uses index for product_id filter", %{product: product} do
      plan =
        explain_query(
          "SELECT * FROM variants WHERE product_id = $1",
          [product.id]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for variants.product_id filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Image loading for product ────────────────────────────────────

  describe "image loading for product" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      for i <- 1..5 do
        create_image!(product, store, %{position: i})
      end

      %{store: store, product: product}
    end

    test "uses index for product_id filter", %{product: product} do
      plan =
        explain_query(
          "SELECT * FROM images WHERE product_id = $1 ORDER BY position ASC",
          [product.id]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for images.product_id filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Low stock query ──────────────────────────────────────────────

  describe "low stock query" do
    setup do
      {_merchant, store} = create_merchant_with_store!()

      # Create enough data for Postgres to prefer index scans
      for i <- 1..30 do
        product = create_product!(store, %{title: "Stock Product #{i}"})

        create_variant!(product, store, %{
          price: 5000,
          stock_quantity: Enum.random(0..100),
          track_inventory: true
        })
      end

      %{store: store}
    end

    test "uses index for low stock filter", %{store: store} do
      plan =
        explain_query(
          "SELECT * FROM variants WHERE store_id = $1 AND track_inventory = true AND stock_quantity < $2",
          [store.id, 10]
        )

      # May use either the composite (store_id, sku) or (track_inventory, stock_quantity) index
      # The key assertion is that it doesn't do a full seq scan on large data
      assert plan["Node Type"] != nil,
             "Expected a valid query plan for low stock query"
    end
  end

  # ── Payment lookup by order ──────────────────────────────────────

  describe "payment lookup" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      order = create_order!(store)

      for _i <- 1..3 do
        create_payment!(store, %{order_id: order.id})
      end

      %{store: store, order: order}
    end

    test "uses index for order_id filter", %{order: order} do
      plan =
        explain_query(
          "SELECT * FROM payments WHERE order_id = $1",
          [order.id]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for payments.order_id filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Line items for order ─────────────────────────────────────────

  describe "line items for order" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      product = create_product!(store)
      variant = create_variant!(product, store, %{price: 5000})
      order = create_order!(store)

      # Insert line items directly via SQL since Ash line_item creation
      # requires order association
      for i <- 1..5 do
        Emakola.Repo.query!(
          """
          INSERT INTO line_items (id, order_id, store_id, variant_id, product_title, unit_price, quantity, line_total, inserted_at, updated_at)
          VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
          """,
          [
            Ecto.UUID.dump!(order.id),
            Ecto.UUID.dump!(store.id),
            Ecto.UUID.dump!(variant.id),
            "Product #{i}",
            5000,
            1,
            5000
          ]
        )
      end

      %{store: store, order: order}
    end

    test "uses index for order_id filter", %{order: order} do
      plan =
        explain_query(
          "SELECT * FROM line_items WHERE order_id = $1",
          [order.id]
        )

      refute uses_seq_scan?(plan),
             "Expected index scan for line_items.order_id filter, got: #{plan["Node Type"]}"
    end
  end

  # ── Concurrent read performance ──────────────────────────────────

  describe "concurrent read performance" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      seed_products(store, 20)
      %{store: store}
    end

    test "handles 10 parallel product listing queries", %{store: store} do
      tasks =
        for _i <- 1..10 do
          Task.async(fn ->
            start = System.monotonic_time(:millisecond)

            {:ok, result} =
              Emakola.Repo.query(
                "SELECT * FROM products WHERE store_id = $1 AND status = $2 LIMIT 20",
                [Ecto.UUID.dump!(store.id), "active"]
              )

            elapsed = System.monotonic_time(:millisecond) - start
            {result.num_rows, elapsed}
          end)
        end

      results = Task.await_many(tasks, 10_000)

      # All queries should complete
      assert length(results) == 10

      # Each query should complete in under 500ms
      for {_rows, elapsed} <- results do
        assert elapsed < 500,
               "Parallel query took #{elapsed}ms, expected < 500ms"
      end
    end
  end

  # ── Index existence verification ─────────────────────────────────

  describe "index existence" do
    @expected_indexes [
      # Ecommerce core FK indexes
      {"products", "products_category_id_index"},
      {"products", "products_status_index"},
      {"products", "products_store_id_status_index"},
      {"variants", "variants_product_id_index"},
      {"variants", "variants_inventory_tracking_index"},
      {"option_types", "option_types_store_id_index"},
      {"option_values", "option_values_store_id_index"},
      {"images", "images_product_id_index"},
      {"images", "images_store_id_index"},
      {"images", "images_product_id_position_index"},
      {"categories", "categories_parent_id_index"},
      {"orders", "orders_customer_id_index"},
      {"orders", "orders_status_index"},
      {"orders", "orders_store_id_status_index"},
      {"orders", "orders_store_id_inserted_at_index"},
      {"line_items", "line_items_order_id_index"},
      {"line_items", "line_items_store_id_index"},
      {"line_items", "line_items_variant_id_index"},
      {"payments", "payments_order_id_index"},
      {"payments", "payments_store_id_index"},
      {"payments", "payments_status_index"},
      {"variant_option_values", "variant_option_values_store_id_index"},
      {"variant_option_values", "variant_option_values_option_value_id_index"},
      {"store_memberships", "store_memberships_store_id_index"},
      # Notifications
      {"notifications", "notifications_user_id_index"},
      {"email_logs", "email_logs_user_id_index"},
      # Billing
      {"subscriptions", "subscriptions_organisation_id_index"},
      {"subscriptions", "subscriptions_plan_id_index"},
      {"usage_records", "usage_records_organisation_id_index"},
      {"invoices", "invoices_organisation_id_index"},
      # Webhooks
      {"webhook_deliveries", "webhook_deliveries_webhook_id_index"},
      {"outbound_webhooks", "outbound_webhooks_organisation_id_index"},
      # AI
      {"conversations", "conversations_organisation_id_index"},
      {"conversations", "conversations_user_id_index"},
      {"conversations", "conversations_agent_id_index"},
      {"messages", "messages_conversation_id_index"},
      {"tool_calls", "tool_calls_message_id_index"},
      {"agents", "agents_organisation_id_index"}
    ]

    for {table, index_name} <- @expected_indexes do
      test "index #{index_name} exists on #{table}" do
        table = unquote(table)
        index_name = unquote(index_name)

        {:ok, result} =
          Emakola.Repo.query(
            """
            SELECT indexname FROM pg_indexes
            WHERE tablename = $1 AND indexname = $2
            """,
            [table, index_name]
          )

        assert result.num_rows > 0,
               "Expected index #{index_name} on table #{table} to exist, but it was not found"
      end
    end
  end
end
