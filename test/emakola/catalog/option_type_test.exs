defmodule Emakola.Catalog.OptionTypeTest do
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
    test "creates an option type with valid attributes", %{store: store, product: product} do
      option_type = create_option_type!(product, store, name: "Size")

      assert option_type.id
      assert option_type.name == "Size"
      assert option_type.product_id == product.id
      assert option_type.store_id == store.id
      assert option_type.position == 0
    end

    test "creates multiple option types for a product", %{store: store, product: product} do
      create_option_type!(product, store, name: "Size")
      create_option_type!(product, store, name: "Color")
      create_option_type!(product, store, name: "Material")

      types =
        Emakola.Catalog.OptionType
        |> Ash.Query.filter(product_id == ^product.id)
        |> Ash.read!(authorize?: false)

      assert length(types) == 3
    end

    test "rejects 4th option type per product", %{store: store, product: product} do
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
               |> Ash.create(authorize?: false)
    end

    test "rejects blank name", %{store: store, product: product} do
      assert {:error, _} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects duplicate name within same product", %{store: store, product: product} do
      create_option_type!(product, store, name: "Size")

      assert {:error, _} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Size",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "allows same name on different products", %{store: store} do
      product_a = create_product!(store, title: "Shirt")
      product_b = create_product!(store, title: "Pants")

      type_a = create_option_type!(product_a, store, name: "Size")
      type_b = create_option_type!(product_b, store, name: "Size")

      assert type_a.name == "Size"
      assert type_b.name == "Size"
      assert type_a.product_id != type_b.product_id
    end
  end

  # ── Update ────────────────────────────────────────────────────

  describe "update" do
    test "updates name", %{store: store, product: product} do
      option_type = create_option_type!(product, store, name: "Size")

      updated =
        option_type
        |> Ash.Changeset.for_update(:update, %{name: "Dress Size"})
        |> Ash.update!(authorize?: false)

      assert updated.name == "Dress Size"
    end

    test "updates position", %{store: store, product: product} do
      option_type = create_option_type!(product, store, name: "Size")

      updated =
        option_type
        |> Ash.Changeset.for_update(:update, %{position: 2})
        |> Ash.update!(authorize?: false)

      assert updated.position == 2
    end
  end

  # ── Destroy ───────────────────────────────────────────────────

  describe "destroy" do
    test "deletes an option type", %{store: store, product: product} do
      option_type = create_option_type!(product, store, name: "Size")
      assert :ok = Ash.destroy!(option_type)
    end
  end

  # ── Multi-tenancy ─────────────────────────────────────────────

  describe "multi-tenant isolation" do
    test "option types scoped to store", %{store: store, product: product} do
      other_store = create_store!(name: "Other", slug: "other-ot")
      other_product = create_product!(other_store, title: "Other Product")

      create_option_type!(product, store, name: "Size")
      create_option_type!(other_product, other_store, name: "Color")

      my_types =
        Emakola.Catalog.OptionType
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(my_types) == 1
      assert hd(my_types).name == "Size"
    end
  end
end
