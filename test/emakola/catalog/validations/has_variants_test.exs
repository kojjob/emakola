defmodule Emakola.Catalog.Validations.HasVariantsTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  describe "validate/3 via activate action" do
    test "rejects activation when product has zero variants", %{store: store} do
      product = create_product!(store, title: "Empty Product")

      assert {:error, _} =
               product
               |> Ash.Changeset.for_update(:activate, %{})
               |> Ash.update(authorize?: false)
    end

    test "passes activation when product has one variant", %{store: store} do
      product = create_product!(store, title: "Single Variant Product")
      _variant = create_variant!(product, store, price: 5000)

      assert {:ok, activated} =
               product
               |> Ash.Changeset.for_update(:activate, %{})
               |> Ash.update(authorize?: false)

      assert activated.status == :active
    end

    test "passes activation when product has many variants", %{store: store} do
      product = create_product!(store, title: "Multi Variant Product")
      _variant1 = create_variant!(product, store, price: 5000)
      _variant2 = create_variant!(product, store, price: 7500)
      _variant3 = create_variant!(product, store, price: 10000)

      assert {:ok, activated} =
               product
               |> Ash.Changeset.for_update(:activate, %{})
               |> Ash.update(authorize?: false)

      assert activated.status == :active
    end

    test "sets published_at timestamp on activation", %{store: store} do
      product = create_product!(store, title: "Publishable")
      _variant = create_variant!(product, store, price: 3000)

      assert {:ok, activated} =
               product
               |> Ash.Changeset.for_update(:activate, %{})
               |> Ash.update(authorize?: false)

      assert activated.published_at != nil
    end

    test "error message mentions variants requirement", %{store: store} do
      product = create_product!(store, title: "No Variants")

      {:error, error} =
        product
        |> Ash.Changeset.for_update(:activate, %{})
        |> Ash.update(authorize?: false)

      error_string = inspect(error)
      assert error_string =~ "variant"
    end
  end

  describe "validate/3 direct call" do
    test "rejects activation for unsaved product (nil id)" do
      changeset =
        Emakola.Catalog.Product
        |> Ash.Changeset.for_create(:create, %{title: "Temp", store_id: Ash.UUID.generate()})

      result =
        Emakola.Catalog.Validations.HasVariants.validate(changeset, [], %{})

      assert {:error, error} = result
      assert error.message =~ "unsaved product"
    end
  end
end
