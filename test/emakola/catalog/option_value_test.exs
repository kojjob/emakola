defmodule Emakola.Catalog.OptionValueTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    product = create_product!(store, title: "T-Shirt")
    option_type = create_option_type!(product, store, name: "Size")
    {:ok, store: store, product: product, option_type: option_type}
  end

  # ── Creation ──────────────────────────────────────────────────

  describe "create" do
    test "creates an option value", %{store: store, option_type: option_type} do
      value = create_option_value!(option_type, store, value: "Small")

      assert value.id
      assert value.value == "Small"
      assert value.option_type_id == option_type.id
      assert value.store_id == store.id
      assert value.position == 0
    end

    test "creates multiple values for an option type", %{store: store, option_type: option_type} do
      create_option_value!(option_type, store, value: "Small")
      create_option_value!(option_type, store, value: "Medium")
      create_option_value!(option_type, store, value: "Large")

      values =
        Emakola.Catalog.OptionValue
        |> Ash.Query.filter(option_type_id == ^option_type.id)
        |> Ash.read!(authorize?: false)

      assert length(values) == 3
    end

    test "rejects blank value", %{store: store, option_type: option_type} do
      assert {:error, _} =
               Emakola.Catalog.OptionValue
               |> Ash.Changeset.for_create(:create, %{
                 value: "",
                 option_type_id: option_type.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects whitespace-only value", %{store: store, option_type: option_type} do
      assert {:error, _} =
               Emakola.Catalog.OptionValue
               |> Ash.Changeset.for_create(:create, %{
                 value: "   ",
                 option_type_id: option_type.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "rejects duplicate value within same option type", %{
      store: store,
      option_type: option_type
    } do
      create_option_value!(option_type, store, value: "Small")

      assert {:error, _} =
               Emakola.Catalog.OptionValue
               |> Ash.Changeset.for_create(:create, %{
                 value: "Small",
                 option_type_id: option_type.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end

    test "allows same value in different option types", %{store: store, product: product} do
      color_type = create_option_type!(product, store, name: "Color")
      size_type = create_option_type!(product, store, name: "Material")

      val_a = create_option_value!(color_type, store, value: "Large")
      val_b = create_option_value!(size_type, store, value: "Large")

      assert val_a.value == "Large"
      assert val_b.value == "Large"
      assert val_a.option_type_id != val_b.option_type_id
    end

    test "enforces max 100 character limit", %{store: store, option_type: option_type} do
      long_value = String.duplicate("a", 101)

      assert {:error, _} =
               Emakola.Catalog.OptionValue
               |> Ash.Changeset.for_create(:create, %{
                 value: long_value,
                 option_type_id: option_type.id,
                 store_id: store.id
               })
               |> Ash.create(authorize?: false)
    end
  end

  # ── Update ────────────────────────────────────────────────────

  describe "update" do
    test "updates value", %{store: store, option_type: option_type} do
      value = create_option_value!(option_type, store, value: "Small")

      updated =
        value
        |> Ash.Changeset.for_update(:update, %{value: "Extra Small"})
        |> Ash.update!(authorize?: false)

      assert updated.value == "Extra Small"
    end

    test "updates position", %{store: store, option_type: option_type} do
      value = create_option_value!(option_type, store, value: "Small")

      updated =
        value
        |> Ash.Changeset.for_update(:update, %{position: 3})
        |> Ash.update!(authorize?: false)

      assert updated.position == 3
    end
  end

  # ── Destroy ───────────────────────────────────────────────────

  describe "destroy" do
    test "deletes an option value", %{store: store, option_type: option_type} do
      value = create_option_value!(option_type, store, value: "Small")
      assert :ok = Ash.destroy!(value, authorize?: false)
    end
  end

  # ── Multi-tenancy ─────────────────────────────────────────────

  describe "multi-tenant isolation" do
    test "option values scoped to store", %{store: store, option_type: option_type} do
      other_store = create_store!(name: "Other", slug: "other-ov")
      other_product = create_product!(other_store, title: "Other")
      other_type = create_option_type!(other_product, other_store, name: "Size")

      create_option_value!(option_type, store, value: "Small")
      create_option_value!(other_type, other_store, value: "Large")

      my_values =
        Emakola.Catalog.OptionValue
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.read!(authorize?: false)

      assert length(my_values) == 1
      assert hd(my_values).value == "Small"
    end
  end
end
