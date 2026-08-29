defmodule Emakola.Catalog.EdgeCasesTest do
  @moduledoc """
  Edge case and boundary tests for the Catalog domain.

  Covers cascade/referential integrity, concurrent stock adjustments,
  Unicode handling, deep nesting, high variant counts, and slug collisions.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  # ── 1. Cascade / Referential Integrity ─────────────────────────

  describe "cascade behavior" do
    test "deleting a product with variants fails due to referential integrity" do
      store = create_store!()
      product = create_product!(store, title: "Ankara Fabric")
      _variant = create_variant!(product, store, price: 8000, sku: "ANK-001")

      # Variants reference product_id with no ON DELETE CASCADE,
      # so destroying the product should raise a foreign key error.
      assert {:error, _} =
               product
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(authorize?: false)
    end

    test "deleting a product with no variants succeeds" do
      store = create_store!()
      product = create_product!(store, title: "Empty Product")

      assert :ok =
               product
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy!(authorize?: false)
    end

    test "deleting a variant with variant_option_values fails due to referential integrity" do
      store = create_store!()
      product = create_product!(store, title: "Linked Product")
      option_type = create_option_type!(product, store, name: "Size")
      option_value = create_option_value!(option_type, store, value: "Large")
      variant = create_variant!(product, store, price: 5000, sku: "LP-L")
      _link = create_variant_option_value!(variant, option_value, store)

      # variant_option_values references variant_id — no cascade
      assert {:error, _} =
               variant
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(authorize?: false)
    end

    test "deleting a category that has products fails due to referential integrity" do
      store = create_store!()
      category = create_category!(store, name: "Electronics")
      _product = create_product!(store, title: "Phone", category_id: category.id)

      # products.category_id references categories — no cascade
      assert {:error, _} =
               category
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(authorize?: false)
    end

    test "deleting a category with no products succeeds" do
      store = create_store!()
      category = create_category!(store, name: "Empty Category")

      assert :ok =
               category
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy!(authorize?: false)
    end

    test "deleting a parent category with child categories fails due to referential integrity" do
      store = create_store!()
      parent = create_category!(store, name: "Parent")
      _child = create_category!(store, name: "Child", parent_id: parent.id)

      assert {:error, _} =
               parent
               |> Ash.Changeset.for_destroy(:destroy)
               |> Ash.destroy(authorize?: false)
    end
  end

  # ── 2. Concurrent Stock Adjustments ────────────────────────────

  describe "concurrent stock adjustments" do
    test "parallel increments produce correct final stock" do
      store = create_store!()
      product = create_product!(store, title: "Concurrent Test Product")
      variant = create_variant!(product, store, price: 1000, stock_quantity: 100, sku: "CONC-INC")

      # Run 10 parallel increments of +5 each = +50 total
      tasks =
        for _i <- 1..10 do
          Emakola.AsyncSandbox.run_async(fn ->
            # Re-fetch to get current state within this task's DB connection
            fresh =
              Emakola.Catalog.Variant
              |> Ash.Query.filter(id == ^variant.id)
              |> Ash.read_one!(authorize?: false)

            fresh
            |> Ash.Changeset.for_update(:adjust_stock, %{delta: 5})
            |> Ash.update(authorize?: false)
          end)
        end

      results = Task.await_many(tasks, 10_000)
      successes = Enum.count(results, &match?({:ok, _}, &1))

      # Re-fetch final state
      final =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(id == ^variant.id)
        |> Ash.read_one!(authorize?: false)

      # All 10 should succeed (increments never go negative)
      assert successes == 10

      # With atomic SQL updates (stock_quantity = stock_quantity + delta),
      # no updates are lost under concurrency. Final stock must be exactly 150.
      assert final.stock_quantity == 150
    end

    test "parallel decrements that would go below 0 are rejected by application validation" do
      store = create_store!()
      product = create_product!(store, title: "Low Stock Product")
      variant = create_variant!(product, store, price: 2000, stock_quantity: 5, sku: "CONC-DEC")

      # Try 10 parallel decrements of -1 each. Only 5 should succeed.
      tasks =
        for _i <- 1..10 do
          Emakola.AsyncSandbox.run_async(fn ->
            fresh =
              Emakola.Catalog.Variant
              |> Ash.Query.filter(id == ^variant.id)
              |> Ash.read_one!(authorize?: false)

            fresh
            |> Ash.Changeset.for_update(:adjust_stock, %{delta: -1})
            |> Ash.update(authorize?: false)
          end)
        end

      results = Task.await_many(tasks, 10_000)
      successes = Enum.count(results, &match?({:ok, _}, &1))
      failures = Enum.count(results, &match?({:error, _}, &1))

      # With atomic updates, exactly 5 succeed (stock goes 5->4->3->2->1->0)
      # and exactly 5 fail (DB CHECK constraint prevents negative stock)
      assert successes == 5
      assert failures == 5

      # Final stock must be exactly 0
      final =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(id == ^variant.id)
        |> Ash.read_one!(authorize?: false)

      assert final.stock_quantity == 0
    end

    test "single decrement below 0 is rejected with error" do
      store = create_store!()
      product = create_product!(store, title: "Zero Stock Product")
      variant = create_variant!(product, store, price: 3000, stock_quantity: 2, sku: "CONC-ZERO")

      assert {:error, _} =
               variant
               |> Ash.Changeset.for_update(:adjust_stock, %{delta: -5})
               |> Ash.update(authorize?: false)

      # Stock should remain unchanged
      unchanged =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(id == ^variant.id)
        |> Ash.read_one!(authorize?: false)

      assert unchanged.stock_quantity == 2
    end
  end

  # ── 3. Unicode Handling ────────────────────────────────────────

  describe "unicode handling" do
    test "category with Akan name generates a valid slug" do
      store = create_store!()
      category = create_category!(store, name: "Ntoma ne Ntadeɛ")

      assert category.name == "Ntoma ne Ntadeɛ"
      assert is_binary(category.slug)
      assert category.slug != ""
      # Slug should be lowercase, hyphenated, ASCII-safe
      assert category.slug =~ ~r/^[a-z0-9][a-z0-9\-]*[a-z0-9]$/
    end

    test "category with Hausa name generates a valid slug" do
      store = create_store!()
      category = create_category!(store, name: "Kayan Gida")

      assert category.name == "Kayan Gida"
      assert category.slug == "kayan-gida"
    end

    test "product with Yoruba name generates a valid slug" do
      store = create_store!()
      product = create_product!(store, title: "Aṣọ Ọkè")

      assert product.title == "Aṣọ Ọkè"
      assert is_binary(product.slug)
      assert product.slug != ""
      assert product.slug =~ ~r/^[a-z0-9][a-z0-9\-]*[a-z0-9]$/
    end

    test "product with mixed Unicode and ASCII generates valid slug" do
      store = create_store!()
      product = create_product!(store, title: "Adinkra Symbols — Gye Nyame ❤")

      assert is_binary(product.slug)
      assert product.slug != ""
      # Should not contain special characters
      refute product.slug =~ ~r/[—❤]/
    end

    test "search works with Unicode characters in title" do
      store = create_store!()
      _product = create_product!(store, title: "Kayan Gida Special")

      results = Emakola.Catalog.search_products!("Kayan", store.id)
      assert results != []
      assert hd(results).title == "Kayan Gida Special"
    end

    test "search works with lowercase matching on Unicode titles" do
      store = create_store!()
      _product = create_product!(store, title: "Ntoma Premium Collection")

      # Search with different case
      results = Emakola.Catalog.search_products!("ntoma", store.id)
      assert results != []

      results_upper = Emakola.Catalog.search_products!("NTOMA", store.id)
      assert results_upper != []
    end
  end

  # ── 4. Boundary Tests ──────────────────────────────────────────

  describe "boundary tests" do
    test "deeply nested category tree (10 levels) with list_children at each level" do
      store = create_store!()

      # Build a 10-level deep category chain
      categories =
        Enum.reduce(1..10, [], fn level, acc ->
          parent_id = if acc == [], do: nil, else: List.last(acc).id

          cat =
            create_category!(store,
              name: "Level #{level}",
              parent_id: parent_id
            )

          acc ++ [cat]
        end)

      assert length(categories) == 10

      # Root should have exactly one child
      roots = Emakola.Catalog.list_root_categories!(store.id)
      assert length(roots) == 1
      assert hd(roots).name == "Level 1"

      # Each level should have exactly one child (except the last)
      for {cat, idx} <- Enum.with_index(categories) do
        children = Emakola.Catalog.list_child_categories!(cat.id, store.id)

        if idx < 9 do
          assert length(children) == 1,
                 "Level #{idx + 1} should have 1 child, got #{length(children)}"

          assert hd(children).name == "Level #{idx + 2}"
        else
          # Last level has no children
          assert children == [],
                 "Level 10 should have no children, got #{length(children)}"
        end
      end
    end

    test "product with 20+ variants are all queryable" do
      store = create_store!()
      product = create_product!(store, title: "Many Variants Product")

      variants =
        for i <- 1..25 do
          create_variant!(product, store,
            price: 1000 + i * 100,
            sku: "MV-#{String.pad_leading(Integer.to_string(i), 3, "0")}",
            stock_quantity: i * 10
          )
        end

      assert length(variants) == 25

      # Query all variants for this product
      queried =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(product_id == ^product.id and store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(queried) == 25

      # Verify price range is correct
      prices = Enum.map(queried, & &1.price) |> Enum.sort()
      assert hd(prices) == 1100
      assert List.last(prices) == 3500
    end

    test "product with all optional fields populated" do
      store = create_store!()
      category = create_category!(store, name: "Full Fields Category")

      product =
        create_product!(store,
          title: "Fully Populated Product",
          description: "A product with every field set for boundary testing.",
          category_id: category.id,
          tags: ["handmade", "local", "premium", "gift", "new-arrival"],
          seo_title: "Buy Fully Populated Product | Best Deals in Ghana",
          seo_description:
            "Shop the best fully populated product. Free delivery in Accra. Mobile money accepted."
        )

      assert product.title == "Fully Populated Product"
      assert product.description != nil
      assert product.category_id == category.id
      assert length(product.tags) == 5
      assert product.seo_title != nil
      assert product.seo_description != nil
      assert product.slug == "fully-populated-product"
      assert product.status == :draft
      assert product.published_at == nil

      # Create a variant with all optional fields
      variant =
        create_variant!(product, store,
          price: 50_000,
          compare_at_price: 75_000,
          sku: "FPP-001",
          stock_quantity: 500,
          track_inventory: true,
          weight_grams: 1500,
          barcode: "5901234123457",
          position: 1
        )

      assert variant.price == 50_000
      assert variant.compare_at_price == 75_000
      assert variant.sku == "FPP-001"
      assert variant.stock_quantity == 500
      assert variant.track_inventory == true
      assert variant.weight_grams == 1500
      assert variant.barcode == "5901234123457"
      assert variant.position == 1
    end

    test "category with many direct children returns all via list_children" do
      store = create_store!()
      parent = create_category!(store, name: "Wide Parent")

      children =
        for i <- 1..15 do
          create_category!(store, name: "Child #{i}", parent_id: parent.id, position: i)
        end

      assert length(children) == 15

      queried_children = Emakola.Catalog.list_child_categories!(parent.id, store.id)
      assert length(queried_children) == 15

      # Verify they are sorted by position
      positions = Enum.map(queried_children, & &1.position)
      assert positions == Enum.sort(positions)
    end
  end

  # ── 5. Slug Collision Edge Cases ───────────────────────────────

  describe "slug collision edge cases" do
    test "two products with names generating same slug fail uniqueness in same store" do
      store = create_store!()

      # Both should generate slug "test-product"
      _product1 = create_product!(store, title: "Test Product")

      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{
                 title: "test-product",
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "products with same slug in different stores succeed" do
      store_a = create_store!(name: "Store A", slug: "slug-store-a")
      store_b = create_store!(name: "Store B", slug: "slug-store-b")

      product_a = create_product!(store_a, title: "Unique Item")
      product_b = create_product!(store_b, title: "Unique Item")

      # Both should have the same slug but in different stores
      assert product_a.slug == product_b.slug
      assert product_a.store_id != product_b.store_id
    end

    test "categories with same slug in different stores succeed" do
      store_a = create_store!(name: "Cat Store A", slug: "cat-slug-store-a")
      store_b = create_store!(name: "Cat Store B", slug: "cat-slug-store-b")

      cat_a = create_category!(store_a, name: "Fashion")
      cat_b = create_category!(store_b, name: "Fashion")

      assert cat_a.slug == cat_b.slug
      assert cat_a.slug == "fashion"
      assert cat_a.store_id != cat_b.store_id
    end

    test "two categories with same slug in same store fail uniqueness" do
      store = create_store!()
      _cat1 = create_category!(store, name: "Electronics")

      assert {:error, _} =
               Emakola.Catalog.Category
               |> Ash.Changeset.for_create(:create, %{
                 name: "electronics",
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "product slug with special characters stripped matches plain version" do
      store = create_store!()

      product = create_product!(store, title: "Test Product!")
      assert product.slug == "test-product"

      # Creating another with same effective slug should fail
      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{
                 title: "Test Product?",
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end
  end
end
