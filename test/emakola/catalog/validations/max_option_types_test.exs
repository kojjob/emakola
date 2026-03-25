defmodule Emakola.Catalog.Validations.MaxOptionTypesTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    product = create_product!(store, title: "T-Shirt")
    {:ok, store: store, product: product}
  end

  describe "validate/3 via create action" do
    test "passes when product has 0 option types (creating first)", %{
      store: store,
      product: product
    } do
      assert {:ok, option_type} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Size",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()

      assert option_type.name == "Size"
    end

    test "passes when product has 1 option type (creating second)", %{
      store: store,
      product: product
    } do
      _first = create_option_type!(product, store, name: "Size")

      assert {:ok, second} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Color",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()

      assert second.name == "Color"
    end

    test "passes when product has 2 option types (creating third — at boundary)", %{
      store: store,
      product: product
    } do
      _first = create_option_type!(product, store, name: "Size")
      _second = create_option_type!(product, store, name: "Color")

      assert {:ok, third} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Material",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()

      assert third.name == "Material"
    end

    test "rejects when product already has 3 option types (creating fourth)", %{
      store: store,
      product: product
    } do
      _first = create_option_type!(product, store, name: "Size")
      _second = create_option_type!(product, store, name: "Color")
      _third = create_option_type!(product, store, name: "Material")

      assert {:error, _} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Style",
                 product_id: product.id,
                 store_id: store.id
               })
               |> Ash.create()
    end

    test "error message mentions maximum option types", %{store: store, product: product} do
      _first = create_option_type!(product, store, name: "Size")
      _second = create_option_type!(product, store, name: "Color")
      _third = create_option_type!(product, store, name: "Material")

      {:error, error} =
        Emakola.Catalog.OptionType
        |> Ash.Changeset.for_create(:create, %{
          name: "Style",
          product_id: product.id,
          store_id: store.id
        })
        |> Ash.create()

      error_string = inspect(error)
      assert error_string =~ "maximum" or error_string =~ "3"
    end

    test "different products have independent option type limits", %{store: store} do
      product_a = create_product!(store, title: "Product A")
      product_b = create_product!(store, title: "Product B")

      # Fill up product A with 3 option types
      _a1 = create_option_type!(product_a, store, name: "Size")
      _a2 = create_option_type!(product_a, store, name: "Color")
      _a3 = create_option_type!(product_a, store, name: "Material")

      # Product B should still accept option types
      assert {:ok, _} =
               Emakola.Catalog.OptionType
               |> Ash.Changeset.for_create(:create, %{
                 name: "Size",
                 product_id: product_b.id,
                 store_id: store.id
               })
               |> Ash.create()
    end
  end

  describe "validate/3 direct call" do
    test "passes when product_id is nil (new product)" do
      changeset =
        Emakola.Catalog.OptionType
        |> Ash.Changeset.for_create(:create, %{
          name: "Size",
          store_id: Ash.UUID.generate()
        })

      assert :ok ==
               Emakola.Catalog.Validations.MaxOptionTypes.validate(changeset, [], %{})
    end
  end
end
