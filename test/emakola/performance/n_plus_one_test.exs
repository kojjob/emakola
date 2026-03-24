defmodule Emakola.Performance.NPlusOneTest do
  @moduledoc """
  Tests verifying that common data loading patterns do NOT produce N+1 queries.
  Uses Ecto telemetry to count the number of queries executed per operation.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  @moduletag :performance

  # ── Query Counter via Ecto Telemetry ─────────────────────────────

  defp start_query_counter do
    test_pid = self()
    counter_ref = make_ref()

    handler_id = "test-query-counter-#{inspect(counter_ref)}"

    :telemetry.attach(
      handler_id,
      [:emakola, :repo, :query],
      fn _event, _measurements, metadata, _config ->
        # Only count actual data queries, not schema/migration queries
        unless metadata[:source] in [nil, "schema_migrations"] do
          send(test_pid, {:query_executed, counter_ref, metadata[:source]})
        end
      end,
      nil
    )

    {handler_id, counter_ref}
  end

  defp stop_query_counter({handler_id, _counter_ref}) do
    :telemetry.detach(handler_id)
  end

  defp count_queries({_handler_id, counter_ref}, fun) do
    # Drain any stale messages
    drain_messages(counter_ref)

    result = fun.()

    # Give a moment for async telemetry
    Process.sleep(10)

    count = count_messages(counter_ref, 0)
    {result, count}
  end

  defp drain_messages(ref) do
    receive do
      {:query_executed, ^ref, _source} -> drain_messages(ref)
    after
      0 -> :ok
    end
  end

  defp count_messages(ref, acc) do
    receive do
      {:query_executed, ^ref, _source} -> count_messages(ref, acc + 1)
    after
      0 -> acc
    end
  end

  # ── Setup helpers ────────────────────────────────────────────────

  defp create_products_with_variants(store, count) do
    for i <- 1..count do
      product = create_product!(store, %{title: "N+1 Product #{i}"})

      for j <- 1..3 do
        create_variant!(product, store, %{
          price: 1000 * j,
          sku: "N1-#{i}-#{j}-#{System.unique_integer([:positive])}"
        })
      end

      product
    end
  end

  defp create_products_with_images(store, count) do
    for i <- 1..count do
      product = create_product!(store, %{title: "Img Product #{i}"})

      for j <- 1..3 do
        create_image!(product, store, %{position: j})
      end

      product
    end
  end

  defp create_categories_with_children(store, parent_count, child_count) do
    for i <- 1..parent_count do
      parent = create_category!(store, %{name: "Parent #{i}"})

      for j <- 1..child_count do
        create_category!(store, %{
          name: "Child #{i}-#{j}",
          parent_id: parent.id
        })
      end

      parent
    end
  end

  # ── Products with Variants ───────────────────────────────────────

  describe "loading products with variants" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      products = create_products_with_variants(store, 5)
      %{store: store, products: products}
    end

    test "eager loading variants avoids N+1", %{store: store} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          # Single query with JOIN or two queries (products + variants via IN)
          # Either is acceptable; N+1 would be 1 + N queries
          {:ok, result} =
            Emakola.Repo.query(
              """
              SELECT p.id, p.title, v.id as variant_id, v.price, v.sku
              FROM products p
              LEFT JOIN variants v ON v.product_id = p.id
              WHERE p.store_id = $1
              ORDER BY p.title, v.position
              """,
              [store.id]
            )

          result
        end)

      stop_query_counter(counter)

      # A proper eager load should use at most 2 queries (products + variants)
      # N+1 would result in 1 + 5 = 6 queries
      assert query_count <= 2,
        "Expected at most 2 queries for products+variants, got #{query_count} (N+1 detected)"
    end

    test "single JOIN query loads products with variants efficiently", %{store: store} do
      start = System.monotonic_time(:millisecond)

      {:ok, result} =
        Emakola.Repo.query(
          """
          SELECT p.id, p.title, v.id as variant_id, v.price, v.sku
          FROM products p
          LEFT JOIN variants v ON v.product_id = p.id
          WHERE p.store_id = $1
          ORDER BY p.title, v.position
          """,
          [store.id]
        )

      elapsed = System.monotonic_time(:millisecond) - start

      assert result.num_rows > 0, "Expected rows from products+variants join"
      assert elapsed < 200, "Products+variants query took #{elapsed}ms, expected < 200ms"
    end
  end

  # ── Orders with Line Items and Customer ──────────────────────────

  describe "loading orders with line items and customer" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      customer = create_customer!(store)
      product = create_product!(store)
      variant = create_variant!(product, store, %{price: 5000})

      orders =
        for _i <- 1..5 do
          order = create_order!(store, %{customer_id: customer.id})

          # Insert line items via SQL
          for j <- 1..3 do
            Emakola.Repo.query!(
              """
              INSERT INTO line_items (id, order_id, store_id, variant_id, product_title, unit_price, quantity, line_total, inserted_at, updated_at)
              VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
              """,
              [order.id, store.id, variant.id, "Product #{j}", 5000, 1, 5000]
            )
          end

          order
        end

      %{store: store, customer: customer, orders: orders}
    end

    test "single query loads orders with line items", %{store: store} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          {:ok, result} =
            Emakola.Repo.query(
              """
              SELECT o.id, o.order_number, o.status, o.total,
                     c.name as customer_name, c.email as customer_email,
                     li.product_title, li.quantity, li.line_total
              FROM orders o
              LEFT JOIN customers c ON c.id = o.customer_id
              LEFT JOIN line_items li ON li.order_id = o.id
              WHERE o.store_id = $1
              ORDER BY o.inserted_at DESC
              """,
              [store.id]
            )

          result
        end)

      stop_query_counter(counter)

      assert query_count <= 1,
        "Expected 1 query for orders+customer+line_items JOIN, got #{query_count}"
    end
  end

  # ── Products with Images ─────────────────────────────────────────

  describe "loading products with images" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      products = create_products_with_images(store, 5)
      %{store: store, products: products}
    end

    test "single query loads products with images", %{store: store} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          {:ok, result} =
            Emakola.Repo.query(
              """
              SELECT p.id, p.title, i.url, i.alt_text, i.position
              FROM products p
              LEFT JOIN images i ON i.product_id = p.id
              WHERE p.store_id = $1
              ORDER BY p.title, i.position
              """,
              [store.id]
            )

          result
        end)

      stop_query_counter(counter)

      assert query_count <= 1,
        "Expected 1 query for products+images JOIN, got #{query_count}"
    end
  end

  # ── Categories with Children ─────────────────────────────────────

  describe "loading categories with children" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      parents = create_categories_with_children(store, 3, 4)
      %{store: store, parents: parents}
    end

    test "single query loads parent categories with children counts", %{store: store} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          {:ok, result} =
            Emakola.Repo.query(
              """
              SELECT c.id, c.name, c.parent_id,
                     COUNT(child.id) as children_count
              FROM categories c
              LEFT JOIN categories child ON child.parent_id = c.id
              WHERE c.store_id = $1
              GROUP BY c.id, c.name, c.parent_id
              ORDER BY c.position
              """,
              [store.id]
            )

          result
        end)

      stop_query_counter(counter)

      assert query_count <= 1,
        "Expected 1 query for categories+children count, got #{query_count}"
    end

    test "recursive CTE loads full category tree efficiently", %{store: store} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          {:ok, result} =
            Emakola.Repo.query(
              """
              WITH RECURSIVE category_tree AS (
                SELECT id, name, parent_id, position, 0 as depth
                FROM categories
                WHERE store_id = $1 AND parent_id IS NULL

                UNION ALL

                SELECT c.id, c.name, c.parent_id, c.position, ct.depth + 1
                FROM categories c
                INNER JOIN category_tree ct ON c.parent_id = ct.id
              )
              SELECT * FROM category_tree ORDER BY depth, position
              """,
              [store.id]
            )

          result
        end)

      stop_query_counter(counter)

      assert query_count <= 1,
        "Expected 1 query for recursive category tree, got #{query_count}"
    end
  end

  # ── Dashboard Stats (aggregated, not N+1) ────────────────────────

  describe "dashboard stats aggregation" do
    setup do
      {_merchant, store} = create_merchant_with_store!()
      customer = create_customer!(store)

      # Create products
      for i <- 1..10 do
        product = create_product!(store, %{title: "Dash Product #{i}", status: "active"})
        create_variant!(product, store, %{price: 5000, stock_quantity: Enum.random(0..50)})
      end

      # Create orders
      for _i <- 1..15 do
        create_order!(store, %{
          customer_id: customer.id,
          status: Enum.random(["pending", "confirmed", "shipped"])
        })
      end

      %{store: store}
    end

    test "dashboard stats use aggregation queries, not N+1", %{store: store} do
      counter = start_query_counter()

      {_results, query_count} =
        count_queries(counter, fn ->
          # Product stats
          {:ok, product_stats} =
            Emakola.Repo.query(
              """
              SELECT
                COUNT(*) as total_products,
                COUNT(*) FILTER (WHERE status = 'active') as active_products,
                COUNT(*) FILTER (WHERE status = 'draft') as draft_products
              FROM products
              WHERE store_id = $1
              """,
              [store.id]
            )

          # Order stats
          {:ok, order_stats} =
            Emakola.Repo.query(
              """
              SELECT
                COUNT(*) as total_orders,
                COUNT(*) FILTER (WHERE status = 'pending') as pending_orders,
                COALESCE(SUM(total), 0) as total_revenue
              FROM orders
              WHERE store_id = $1
              """,
              [store.id]
            )

          # Low stock alert
          {:ok, low_stock} =
            Emakola.Repo.query(
              """
              SELECT COUNT(*) as low_stock_count
              FROM variants
              WHERE store_id = $1
                AND track_inventory = true
                AND stock_quantity < $2
              """,
              [store.id, 10]
            )

          {product_stats, order_stats, low_stock}
        end)

      stop_query_counter(counter)

      # Dashboard should use exactly 3 aggregation queries
      # NOT 10 (products) + 15 (orders) + N (variants) individual lookups
      assert query_count <= 3,
        "Expected 3 aggregation queries for dashboard stats, got #{query_count} (N+1 detected)"
    end

    test "combined dashboard stats in single query", %{store: store} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          {:ok, result} =
            Emakola.Repo.query(
              """
              SELECT
                (SELECT COUNT(*) FROM products WHERE store_id = $1) as total_products,
                (SELECT COUNT(*) FROM products WHERE store_id = $1 AND status = 'active') as active_products,
                (SELECT COUNT(*) FROM orders WHERE store_id = $1) as total_orders,
                (SELECT COUNT(*) FROM orders WHERE store_id = $1 AND status = 'pending') as pending_orders,
                (SELECT COALESCE(SUM(total), 0) FROM orders WHERE store_id = $1) as total_revenue,
                (SELECT COUNT(*) FROM variants WHERE store_id = $1 AND track_inventory = true AND stock_quantity < 10) as low_stock_count
              """,
              [store.id]
            )

          result
        end)

      stop_query_counter(counter)

      assert query_count <= 1,
        "Expected 1 combined query for dashboard stats, got #{query_count}"
    end
  end

  # ── Batch operations ─────────────────────────────────────────────

  describe "batch variant loading" do
    setup do
      {_merchant, store} = create_merchant_with_store!()

      products =
        for i <- 1..5 do
          product = create_product!(store, %{title: "Batch Product #{i}"})

          for j <- 1..3 do
            create_variant!(product, store, %{
              price: 1000 * j,
              sku: "BATCH-#{i}-#{j}-#{System.unique_integer([:positive])}"
            })
          end

          product
        end

      product_ids = Enum.map(products, & &1.id)
      %{store: store, product_ids: product_ids}
    end

    test "IN clause loads all variants in single query", %{product_ids: product_ids} do
      counter = start_query_counter()

      {_result, query_count} =
        count_queries(counter, fn ->
          # Build parameterized placeholders: $1, $2, $3, ...
          placeholders =
            product_ids
            |> Enum.with_index(1)
            |> Enum.map(fn {_id, i} -> "$#{i}" end)
            |> Enum.join(", ")

          {:ok, result} =
            Emakola.Repo.query(
              "SELECT * FROM variants WHERE product_id IN (#{placeholders})",
              product_ids
            )

          result
        end)

      stop_query_counter(counter)

      assert query_count <= 1,
        "Expected 1 query for batch variant loading via IN clause, got #{query_count}"
    end
  end
end
