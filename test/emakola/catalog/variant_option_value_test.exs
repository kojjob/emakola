defmodule Emakola.Catalog.VariantOptionValueTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "T-Shirt")
    size_type = create_option_type!(product, store, name: "Size")
    color_type = create_option_type!(product, store, name: "Color")
    small = create_option_value!(size_type, store, value: "Small")
    large = create_option_value!(size_type, store, value: "Large")
    red = create_option_value!(color_type, store, value: "Red")
    blue = create_option_value!(color_type, store, value: "Blue")
    variant = create_variant!(product, store, price: 5000, sku: "TSHIRT-SM-RED")

    {:ok,
     store: store,
     product: product,
     size_type: size_type,
     color_type: color_type,
     small: small,
     large: large,
     red: red,
     blue: blue,
     variant: variant}
  end

  # ── Creation ──────────────────────────────────────────────────

  describe "create" do
    test "links a variant to an option value", %{store: store, variant: variant, small: small} do
      vov = create_variant_option_value!(variant, small, store)

      assert vov.id
      assert vov.variant_id == variant.id
      assert vov.option_value_id == small.id
      assert vov.store_id == store.id
    end

    test "links variant to multiple option values", %{
      store: store,
      variant: variant,
      small: small,
      red: red
    } do
      create_variant_option_value!(variant, small, store)
      create_variant_option_value!(variant, red, store)

      links =
        Emakola.Catalog.VariantOptionValue
        |> Ash.Query.filter(variant_id == ^variant.id)
        |> Ash.read!(authorize?: false)

      assert length(links) == 2
    end

    test "rejects duplicate variant + option_value combination", %{
      store: store,
      variant: variant,
      small: small
    } do
      create_variant_option_value!(variant, small, store)

      assert {:error, _} =
               Emakola.Catalog.VariantOptionValue
               |> Ash.Changeset.for_create(:create, %{
                 variant_id: variant.id,
                 option_value_id: small.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end
  end

  # ── Variant matrix ────────────────────────────────────────────

  describe "variant matrix" do
    test "creates 2x2 variant matrix (Size × Color)", %{
      store: store,
      product: product,
      small: small,
      large: large,
      red: red,
      blue: blue
    } do
      # 4 variants: Small-Red, Small-Blue, Large-Red, Large-Blue
      v_sm_red = create_variant!(product, store, price: 5000, sku: "SM-RED")
      v_sm_blue = create_variant!(product, store, price: 5000, sku: "SM-BLUE")
      v_lg_red = create_variant!(product, store, price: 5500, sku: "LG-RED")
      v_lg_blue = create_variant!(product, store, price: 5500, sku: "LG-BLUE")

      # Link each variant to its option values
      create_variant_option_value!(v_sm_red, small, store)
      create_variant_option_value!(v_sm_red, red, store)

      create_variant_option_value!(v_sm_blue, small, store)
      create_variant_option_value!(v_sm_blue, blue, store)

      create_variant_option_value!(v_lg_red, large, store)
      create_variant_option_value!(v_lg_red, red, store)

      create_variant_option_value!(v_lg_blue, large, store)
      create_variant_option_value!(v_lg_blue, blue, store)

      # Verify each variant has exactly 2 option values
      for variant <- [v_sm_red, v_sm_blue, v_lg_red, v_lg_blue] do
        links =
          Emakola.Catalog.VariantOptionValue
          |> Ash.Query.filter(variant_id == ^variant.id)
          |> Ash.read!(authorize?: false)

        assert length(links) == 2
      end

      # Verify total links = 8 (4 variants × 2 options each)
      all_links =
        Emakola.Catalog.VariantOptionValue
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      # 8 from matrix + 0 from setup variant (not linked)
      assert length(all_links) == 8
    end
  end

  # ── Destroy ───────────────────────────────────────────────────

  describe "destroy" do
    test "deletes a variant-option-value link", %{store: store, variant: variant, small: small} do
      vov = create_variant_option_value!(variant, small, store)
      assert :ok = Ash.destroy!(vov)

      links =
        Emakola.Catalog.VariantOptionValue
        |> Ash.Query.filter(variant_id == ^variant.id)
        |> Ash.read!(authorize?: false)

      assert links == []
    end
  end

  # ── Multi-tenancy ─────────────────────────────────────────────

  describe "multi-tenant isolation" do
    test "variant option values scoped to store", %{
      store: store,
      variant: variant,
      small: small
    } do
      other_store = create_store!(name: "Other", slug: "other-vov")
      other_product = create_product!(other_store, title: "Other Shirt")
      other_type = create_option_type!(other_product, other_store, name: "Size")
      other_val = create_option_value!(other_type, other_store, value: "XL")
      other_variant = create_variant!(other_product, other_store, price: 3000)

      create_variant_option_value!(variant, small, store)
      create_variant_option_value!(other_variant, other_val, other_store)

      my_links =
        Emakola.Catalog.VariantOptionValue
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(my_links) == 1
    end
  end
end
