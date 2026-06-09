defmodule Emakola.Catalog.VariantTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "T-Shirt")
    {:ok, store: store, product: product}
  end

  # ── Creation ──────────────────────────────────────────────────

  describe "create" do
    test "creates a variant with valid attributes", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, sku: "TSHIRT-001")

      assert variant.id
      assert variant.price == 5000
      assert variant.sku == "TSHIRT-001"
      assert variant.product_id == product.id
      assert variant.store_id == store.id
      assert variant.stock_quantity == 0
      assert variant.track_inventory == true
      assert variant.position == 0
    end

    test "creates variant without SKU (single-variant products)", %{
      store: store,
      product: product
    } do
      variant = create_variant!(product, store, price: 3000)
      assert is_nil(variant.sku)
    end

    test "creates variant with compare_at_price", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, compare_at_price: 8000)
      assert variant.compare_at_price == 8000
    end

    test "creates variant with stock quantity", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, stock_quantity: 100)
      assert variant.stock_quantity == 100
    end

    test "creates variant with weight and barcode", %{store: store, product: product} do
      variant =
        create_variant!(product, store, price: 5000, weight_grams: 250, barcode: "1234567890")

      assert variant.weight_grams == 250
      assert variant.barcode == "1234567890"
    end
  end

  # ── Validations ───────────────────────────────────────────────

  describe "validations" do
    test "rejects zero price", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: 0,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects negative price", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: -100,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects compare_at_price less than price", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: 5000,
                 compare_at_price: 3000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects compare_at_price equal to price", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: 5000,
                 compare_at_price: 5000,
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects duplicate SKU within same store", %{store: store, product: product} do
      create_variant!(product, store, price: 5000, sku: "DUPE-SKU")

      other_product = create_product!(store, title: "Pants")

      assert {:error, _} =
               Emakola.Catalog.Variant
               |> Ash.Changeset.for_create(:create, %{
                 price: 3000,
                 sku: "DUPE-SKU",
                 product_id: other_product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "allows same SKU in different stores", %{product: product, store: store} do
      create_variant!(product, store, price: 5000, sku: "SHARED-SKU")

      other_store = create_store!(name: "Other", slug: "other-var")
      other_product = create_product!(other_store, title: "Other Product")

      variant_b =
        create_variant!(other_product, other_store, price: 3000, sku: "SHARED-SKU")

      assert variant_b.sku == "SHARED-SKU"
    end
  end

  # ── Stock management ──────────────────────────────────────────

  describe "adjust_stock" do
    test "increments stock quantity", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, stock_quantity: 10)

      updated =
        variant
        |> Ash.Changeset.for_update(:adjust_stock, %{delta: 5})
        |> Ash.update!(authorize?: false)

      assert updated.stock_quantity == 15
    end

    test "decrements stock quantity", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, stock_quantity: 10)

      updated =
        variant
        |> Ash.Changeset.for_update(:adjust_stock, %{delta: -3})
        |> Ash.update!(authorize?: false)

      assert updated.stock_quantity == 7
    end

    test "rejects decrement below zero", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, stock_quantity: 5)

      assert {:error, _} =
               variant
               |> Ash.Changeset.for_update(:adjust_stock, %{delta: -10})
               |> Ash.update(authorize?: false)
    end

    test "allows decrement to exactly zero", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000, stock_quantity: 5)

      updated =
        variant
        |> Ash.Changeset.for_update(:adjust_stock, %{delta: -5})
        |> Ash.update!(authorize?: false)

      assert updated.stock_quantity == 0
    end
  end

  # ── Low stock query ───────────────────────────────────────────

  describe "low_stock" do
    test "returns variants below threshold", %{store: store, product: product} do
      create_variant!(product, store, price: 5000, stock_quantity: 3, sku: "LOW-1")
      create_variant!(product, store, price: 3000, stock_quantity: 50, sku: "HIGH-1")
      create_variant!(product, store, price: 2000, stock_quantity: 1, sku: "LOW-2")

      low = Emakola.Catalog.list_low_stock!(5, store.id)

      assert length(low) == 2
      assert Enum.all?(low, &(&1.stock_quantity < 5))
    end

    test "excludes variants with track_inventory false", %{store: store, product: product} do
      create_variant!(product, store,
        price: 5000,
        stock_quantity: 0,
        track_inventory: false,
        sku: "NO-TRACK"
      )

      create_variant!(product, store,
        price: 3000,
        stock_quantity: 0,
        track_inventory: true,
        sku: "TRACK"
      )

      low = Emakola.Catalog.list_low_stock!(10, store.id)

      assert length(low) == 1
      assert hd(low).sku == "TRACK"
    end
  end

  # ── Update ────────────────────────────────────────────────────

  describe "update" do
    test "updates price", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000)

      updated =
        variant
        |> Ash.Changeset.for_update(:update, %{price: 7500})
        |> Ash.update!(authorize?: false)

      assert updated.price == 7500
    end

    test "updates SKU", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000)

      updated =
        variant
        |> Ash.Changeset.for_update(:update, %{sku: "NEW-SKU"})
        |> Ash.update!(authorize?: false)

      assert updated.sku == "NEW-SKU"
    end
  end

  # ── Dropshipping ──────────────────────────────────────────────

  describe "dropship fields" do
    test "accepts cost_price and available", %{store: store, product: product} do
      supplier = create_supplier!(store)

      variant =
        create_variant!(product, store,
          price: 5000,
          cost_price: 3000,
          available: false,
          supplier_id: supplier.id
        )

      assert variant.cost_price == 3000
      assert variant.available == false
      assert variant.supplier_id == supplier.id
    end

    test "available defaults to true", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000)
      assert variant.available == true
    end

    test "supplier_id is nullable for own-stock variants", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000)
      assert is_nil(variant.supplier_id)
      assert variant.track_inventory == true
    end

    test "setting supplier_id on create forces track_inventory to false", %{
      store: store,
      product: product
    } do
      supplier = create_supplier!(store)

      variant =
        create_variant!(product, store,
          price: 5000,
          supplier_id: supplier.id,
          track_inventory: true
        )

      assert variant.supplier_id == supplier.id
      assert variant.track_inventory == false
    end

    test "setting supplier_id on update forces track_inventory to false", %{
      store: store,
      product: product
    } do
      supplier = create_supplier!(store)
      variant = create_variant!(product, store, price: 5000, track_inventory: true)
      assert variant.track_inventory == true

      updated =
        variant
        |> Ash.Changeset.for_update(:update, %{supplier_id: supplier.id, track_inventory: true})
        |> Ash.update!(authorize?: false)

      assert updated.supplier_id == supplier.id
      assert updated.track_inventory == false
    end
  end

  # ── Multi-tenancy ─────────────────────────────────────────────

  describe "multi-tenant isolation" do
    test "variants scoped to store", %{store: store, product: product} do
      other_store = create_store!(name: "Other", slug: "other-variant")
      other_product = create_product!(other_store, title: "Other")

      create_variant!(product, store, price: 5000)
      create_variant!(other_product, other_store, price: 3000)

      my_variants =
        Emakola.Catalog.Variant
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(my_variants) == 1
    end
  end

  # ── Destroy ───────────────────────────────────────────────────

  describe "destroy" do
    test "deletes a variant", %{store: store, product: product} do
      variant = create_variant!(product, store, price: 5000)
      assert :ok = Ash.destroy!(variant)
    end
  end
end
