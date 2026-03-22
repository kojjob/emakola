defmodule Emakola.Catalog.ProductTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    category = create_category!(store, name: "Electronics")
    {:ok, store: store, category: category}
  end

  # ── Creation ──────────────────────────────────────────────────

  describe "create" do
    test "creates a product with valid attributes", %{store: store, category: category} do
      product = create_product!(store, title: "iPhone 15", category_id: category.id)

      assert product.id
      assert product.title == "iPhone 15"
      assert product.store_id == store.id
      assert product.slug == "iphone-15"
      assert product.status == :draft
      assert product.category_id == category.id
      assert is_nil(product.published_at)
    end

    test "auto-generates slug from title", %{store: store} do
      product = create_product!(store, title: "Samsung Galaxy S24 Ultra (256GB)")
      assert product.slug == "samsung-galaxy-s24-ultra-256gb"
    end

    test "defaults status to draft", %{store: store} do
      product = create_product!(store, title: "Test Product")
      assert product.status == :draft
    end

    test "defaults tags to empty list", %{store: store} do
      product = create_product!(store, title: "Test Product")
      assert product.tags == []
    end

    test "creates product with tags", %{store: store} do
      product = create_product!(store, title: "Test", tags: ["sale", "new-arrival"])
      assert product.tags == ["sale", "new-arrival"]
    end

    test "creates product with SEO fields", %{store: store} do
      product =
        create_product!(store,
          title: "Test",
          seo_title: "Buy Test Product in Ghana",
          seo_description: "Best prices on Test Product"
        )

      assert product.seo_title == "Buy Test Product in Ghana"
      assert product.seo_description == "Best prices on Test Product"
    end

    test "rejects blank title", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{title: "", store_id: store.id})
               |> Ash.create()
    end

    test "rejects nil title", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{store_id: store.id})
               |> Ash.create()
    end

    test "product without category is valid", %{store: store} do
      product = create_product!(store, title: "Uncategorized Item")
      assert is_nil(product.category_id)
    end
  end

  # ── Slug uniqueness ───────────────────────────────────────────

  describe "slug uniqueness" do
    test "rejects duplicate slug within same store", %{store: store} do
      create_product!(store, title: "iPhone")

      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{title: "iPhone", store_id: store.id})
               |> Ash.create()
    end

    test "allows same slug in different stores" do
      store_a = create_store!(name: "Store A", slug: "store-a-prod")
      store_b = create_store!(name: "Store B", slug: "store-b-prod")

      prod_a = create_product!(store_a, title: "iPhone")
      prod_b = create_product!(store_b, title: "iPhone")

      assert prod_a.slug == "iphone"
      assert prod_b.slug == "iphone"
      assert prod_a.store_id != prod_b.store_id
    end
  end

  # ── Multi-tenancy ─────────────────────────────────────────────

  describe "multi-tenant isolation" do
    test "products are scoped to store", %{store: store} do
      other_store = create_store!(name: "Other Store", slug: "other-store-prod")

      create_product!(store, title: "My Product")
      create_product!(other_store, title: "Their Product")

      my_products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!()

      assert length(my_products) == 1
      assert hd(my_products).title == "My Product"
    end
  end

  # ── Status transitions ───────────────────────────────────────

  describe "status transitions" do
    test "archive transitions draft to archived", %{store: store} do
      product = create_product!(store, title: "To Archive")

      archived =
        product
        |> Ash.Changeset.for_update(:archive, %{})
        |> Ash.update!()

      assert archived.status == :archived
    end

    test "activate fails without variants", %{store: store} do
      product = create_product!(store, title: "Empty Product")

      assert {:error, _} =
               product
               |> Ash.Changeset.for_update(:activate, %{})
               |> Ash.update()
    end

    test "activate succeeds with at least one variant", %{store: store} do
      product = create_product!(store, title: "Ready Product")
      create_variant!(product, store, price: 5000)

      activated =
        product
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!()

      assert activated.status == :active
      assert activated.published_at != nil
    end

    test "activate then archive", %{store: store} do
      product = create_product!(store, title: "Full Lifecycle")
      create_variant!(product, store, price: 5000)

      activated =
        product
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!()

      assert activated.status == :active

      archived =
        activated
        |> Ash.Changeset.for_update(:archive, %{})
        |> Ash.update!()

      assert archived.status == :archived
    end
  end

  # ── Update ────────────────────────────────────────────────────

  describe "update" do
    test "updates title and regenerates slug", %{store: store} do
      product = create_product!(store, title: "Old Name")

      updated =
        product
        |> Ash.Changeset.for_update(:update, %{title: "New Name"})
        |> Ash.update!()

      assert updated.title == "New Name"
      assert updated.slug == "new-name"
    end

    test "updates description", %{store: store} do
      product = create_product!(store, title: "Test")

      updated =
        product
        |> Ash.Changeset.for_update(:update, %{description: "Updated description"})
        |> Ash.update!()

      assert updated.description == "Updated description"
    end

    test "updates tags", %{store: store} do
      product = create_product!(store, title: "Test")

      updated =
        product
        |> Ash.Changeset.for_update(:update, %{tags: ["promo", "featured"]})
        |> Ash.update!()

      assert updated.tags == ["promo", "featured"]
    end

    test "updates category", %{store: store, category: _category} do
      product = create_product!(store, title: "Test")
      new_category = create_category!(store, name: "Clothing")

      updated =
        product
        |> Ash.Changeset.for_update(:update, %{category_id: new_category.id})
        |> Ash.update!()

      assert updated.category_id == new_category.id
    end
  end

  # ── Search ────────────────────────────────────────────────────

  describe "search" do
    test "search finds products by title", %{store: store} do
      create_product!(store, title: "Dangote Cement 50kg")
      create_product!(store, title: "Samsung Phone")
      create_product!(store, title: "Dangote Sugar 1kg")

      results = Emakola.Catalog.search_products!("dangote", store.id)

      assert length(results) == 2
      assert Enum.all?(results, &String.contains?(&1.title, "Dangote"))
    end

    test "search is case-insensitive", %{store: store} do
      create_product!(store, title: "Dangote Cement")

      results = Emakola.Catalog.search_products!("dangote", store.id)
      assert length(results) == 1
    end

    test "search returns empty for no matches", %{store: store} do
      create_product!(store, title: "Samsung Phone")

      results = Emakola.Catalog.search_products!("nonexistent", store.id)
      assert results == []
    end
  end

  # ── List by category ──────────────────────────────────────────

  describe "list_by_category" do
    test "returns products in a specific category", %{store: store, category: category} do
      create_product!(store, title: "Phone", category_id: category.id)
      create_product!(store, title: "Laptop", category_id: category.id)

      other_cat = create_category!(store, name: "Clothing")
      create_product!(store, title: "Shirt", category_id: other_cat.id)

      products = Emakola.Catalog.list_products_by_category!(category.id, store.id)

      assert length(products) == 2
      assert Enum.all?(products, &(&1.category_id == category.id))
    end
  end

  # ── Destroy ───────────────────────────────────────────────────

  describe "destroy" do
    test "deletes a product", %{store: store} do
      product = create_product!(store, title: "To Delete")

      assert :ok = Ash.destroy!(product)

      assert [] =
               Emakola.Catalog.Product
               |> Ash.Query.filter(store_id == ^store.id)
               |> Ash.read!()
    end
  end

  # ── Aggregates ────────────────────────────────────────────────

  describe "aggregates" do
    test "variant_count returns 0 for product with no variants", %{store: store} do
      product = create_product!(store, title: "Empty Product")

      loaded =
        Emakola.Catalog.Product
        |> Ash.Query.filter(id == ^product.id)
        |> Ash.Query.load([:variant_count])
        |> Ash.read_one!()

      assert loaded.variant_count == 0
    end

    test "variant_count returns correct count", %{store: store} do
      product = create_product!(store, title: "Multi-variant")
      create_variant!(product, store, price: 5000, sku: "V1")
      create_variant!(product, store, price: 7000, sku: "V2")
      create_variant!(product, store, price: 3000, sku: "V3")

      loaded =
        Emakola.Catalog.Product
        |> Ash.Query.filter(id == ^product.id)
        |> Ash.Query.load([:variant_count, :min_price, :max_price])
        |> Ash.read_one!()

      assert loaded.variant_count == 3
      assert loaded.min_price == 3000
      assert loaded.max_price == 7000
    end

    test "min_price and max_price are nil for product with no variants", %{store: store} do
      product = create_product!(store, title: "No Variants")

      loaded =
        Emakola.Catalog.Product
        |> Ash.Query.filter(id == ^product.id)
        |> Ash.Query.load([:min_price, :max_price])
        |> Ash.read_one!()

      assert is_nil(loaded.min_price)
      assert is_nil(loaded.max_price)
    end

    test "min_price equals max_price for single variant", %{store: store} do
      product = create_product!(store, title: "Single Variant")
      create_variant!(product, store, price: 4500, sku: "ONLY")

      loaded =
        Emakola.Catalog.Product
        |> Ash.Query.filter(id == ^product.id)
        |> Ash.Query.load([:variant_count, :min_price, :max_price])
        |> Ash.read_one!()

      assert loaded.variant_count == 1
      assert loaded.min_price == 4500
      assert loaded.max_price == 4500
    end
  end

  # ── Edge cases ────────────────────────────────────────────────

  describe "edge cases" do
    test "whitespace-only title is rejected", %{store: store} do
      assert {:error, _} =
               Emakola.Catalog.Product
               |> Ash.Changeset.for_create(:create, %{title: "   ", store_id: store.id})
               |> Ash.create()
    end

    test "Unicode title generates valid slug", %{store: store} do
      product = create_product!(store, title: "Kente Cloth - Traditional Ghanaian")
      assert product.slug
      assert is_binary(product.slug)
      assert String.length(product.slug) > 0
    end
  end
end
