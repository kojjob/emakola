defmodule Emakola.Catalog.IntegrationTest do
  @moduledoc """
  Integration tests for the full Catalog domain.

  Tests end-to-end flows across Category, Product, OptionType, OptionValue,
  Variant, and VariantOptionValue resources.
  """
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  # ── Full product lifecycle ────────────────────────────────────

  describe "full product lifecycle" do
    test "create → add options → generate variants → activate → archive" do
      # 1. Setup store and category
      store = create_store!(name: "Kojo's Fashion", slug: "kojos-fashion", currency: "GHS")
      category = create_category!(store, name: "Men's Clothing")

      # 2. Create product
      product = create_product!(store, title: "Kente Print Shirt", category_id: category.id)
      assert product.status == :draft

      # 3. Add option types
      size_type = create_option_type!(product, store, name: "Size")
      color_type = create_option_type!(product, store, name: "Color")

      # 4. Add option values
      small = create_option_value!(size_type, store, value: "Small")
      medium = create_option_value!(size_type, store, value: "Medium")
      large = create_option_value!(size_type, store, value: "Large")

      red = create_option_value!(color_type, store, value: "Red")
      blue = create_option_value!(color_type, store, value: "Blue")

      # 5. Create variant matrix (3 sizes × 2 colors = 6 variants)
      variants =
        for {size, size_val} <- [{"S", small}, {"M", medium}, {"L", large}],
            {color, color_val} <- [{"RED", red}, {"BLU", blue}] do
          # Price in pesewas: 15000 = GHS 150.00
          variant =
            create_variant!(product, store,
              price: 15_000,
              sku: "KENTE-#{size}-#{color}",
              stock_quantity: 25
            )

          create_variant_option_value!(variant, size_val, store)
          create_variant_option_value!(variant, color_val, store)
          variant
        end

      assert length(variants) == 6

      # 6. Verify each variant has 2 option values
      for variant <- variants do
        links =
          Emakola.Catalog.VariantOptionValue
          |> Ash.Query.filter(variant_id == ^variant.id)
          |> Ash.read!()

        assert length(links) == 2
      end

      # 7. Activate product (should succeed — has variants)
      activated =
        product
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!()

      assert activated.status == :active
      assert activated.published_at != nil

      # 8. Archive product
      archived =
        activated
        |> Ash.Changeset.for_update(:archive, %{})
        |> Ash.update!()

      assert archived.status == :archived
    end
  end

  # ── Multi-tenant isolation (cross-resource) ──────────────────

  describe "multi-tenant isolation across resources" do
    test "store A cannot see store B's catalog data" do
      store_a = create_store!(name: "Store A", slug: "store-a-int")
      store_b = create_store!(name: "Store B", slug: "store-b-int")

      # Create full catalog in Store A
      cat_a = create_category!(store_a, name: "Electronics")
      prod_a = create_product!(store_a, title: "Phone", category_id: cat_a.id)
      type_a = create_option_type!(prod_a, store_a, name: "Storage")
      val_a = create_option_value!(type_a, store_a, value: "128GB")
      var_a = create_variant!(prod_a, store_a, price: 500_000, sku: "PHONE-128")
      create_variant_option_value!(var_a, val_a, store_a)

      # Create full catalog in Store B
      cat_b = create_category!(store_b, name: "Food")
      prod_b = create_product!(store_b, title: "Jollof Rice", category_id: cat_b.id)
      var_b = create_variant!(prod_b, store_b, price: 3500)

      # Store A queries should only see Store A data
      a_categories =
        Emakola.Catalog.Category
        |> Ash.Query.filter(store_id == ^store_a.id)
        |> Ash.read!()

      assert length(a_categories) == 1
      assert hd(a_categories).name == "Electronics"

      a_products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store_a.id)
        |> Ash.read!()

      assert length(a_products) == 1
      assert hd(a_products).title == "Phone"

      a_variants =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(store_id == ^store_a.id)
        |> Ash.read!()

      assert length(a_variants) == 1
      assert hd(a_variants).price == 500_000

      # Store B should only see its own
      b_products =
        Emakola.Catalog.Product
        |> Ash.Query.filter(store_id == ^store_b.id)
        |> Ash.read!()

      assert length(b_products) == 1
      assert hd(b_products).title == "Jollof Rice"
    end
  end

  # ── Category tree with products ──────────────────────────────

  describe "category tree with products" do
    test "products organized in nested categories" do
      store = create_store!()

      # Build tree: Building Materials → Cement → Dangote
      materials = create_category!(store, name: "Building Materials")
      cement = create_category!(store, name: "Cement", parent_id: materials.id)
      _dangote = create_category!(store, name: "Dangote Cement", parent_id: cement.id)

      # Products in different levels
      create_product!(store, title: "General Concrete", category_id: materials.id)
      create_product!(store, title: "Portland Cement 50kg", category_id: cement.id)
      create_product!(store, title: "Dangote 3X 50kg", category_id: cement.id)

      # Query products in Cement category
      cement_products = Emakola.Catalog.list_products_by_category!(cement.id, store.id)
      assert length(cement_products) == 2

      # Query root categories
      roots = Emakola.Catalog.list_root_categories!(store.id)
      assert length(roots) == 1
      assert hd(roots).name == "Building Materials"

      # Query children of Building Materials
      children = Emakola.Catalog.list_child_categories!(materials.id, store.id)
      assert length(children) == 1
      assert hd(children).name == "Cement"
    end
  end

  # ── Stock management integration ─────────────────────────────

  describe "stock management" do
    test "stock adjustments across multiple variants" do
      store = create_store!()
      product = create_product!(store, title: "T-Shirt")

      v1 = create_variant!(product, store, price: 5000, stock_quantity: 100, sku: "TS-S")
      v2 = create_variant!(product, store, price: 5000, stock_quantity: 50, sku: "TS-M")
      v3 = create_variant!(product, store, price: 5000, stock_quantity: 5, sku: "TS-L")

      # Sell some stock
      v1 = v1 |> Ash.Changeset.for_update(:adjust_stock, %{delta: -10}) |> Ash.update!()
      v2 = v2 |> Ash.Changeset.for_update(:adjust_stock, %{delta: -45}) |> Ash.update!()
      v3 = v3 |> Ash.Changeset.for_update(:adjust_stock, %{delta: -5}) |> Ash.update!()

      assert v1.stock_quantity == 90
      assert v2.stock_quantity == 5
      assert v3.stock_quantity == 0

      # Check low stock
      low = Emakola.Catalog.list_low_stock!(10, store.id)
      assert length(low) == 2
      skus = Enum.map(low, & &1.sku) |> Enum.sort()
      assert skus == ["TS-L", "TS-M"]
    end
  end

  # ── Edge cases ────────────────────────────────────────────────

  describe "edge cases" do
    test "product with single variant (no options) can be activated" do
      store = create_store!()
      product = create_product!(store, title: "Simple Product")
      create_variant!(product, store, price: 1000)

      activated =
        product
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update!()

      assert activated.status == :active
    end

    test "max 3 option types enforced even with variants" do
      store = create_store!()
      product = create_product!(store, title: "Complex Product")

      create_option_type!(product, store, name: "Size")
      create_option_type!(product, store, name: "Color")
      create_option_type!(product, store, name: "Material")

      assert {:error, _} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Weight",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()
    end

    test "money is always in integer minor units" do
      store = create_store!(currency: "GHS")
      product = create_product!(store, title: "Test")

      # GHS 150.00 = 15000 pesewas
      variant = create_variant!(product, store, price: 15_000, compare_at_price: 20_000)

      assert variant.price == 15_000
      assert variant.compare_at_price == 20_000
      assert is_integer(variant.price)
      assert is_integer(variant.compare_at_price)
    end
  end
end
