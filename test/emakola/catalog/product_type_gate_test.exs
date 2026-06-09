defmodule Emakola.Catalog.ProductTypeGateTest do
  @moduledoc """
  The store-level capability gate: a product's `product_type` must be
  present in `store.enabled_product_types` for both creates and updates.

  See `Emakola.Catalog.Validations.ProductTypeAcceptedByStore`.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Catalog.Product

  setup do
    {:ok, store: create_store!()}
  end

  defp enable_type(store, type) do
    types =
      [type | store.enabled_product_types]
      |> Enum.uniq()

    store
    |> Ash.Changeset.for_update(:update_settings, %{enabled_product_types: types})
    |> Ash.update!(authorize?: false)
  end

  defp create_product(store, attrs) do
    Product
    |> Ash.Changeset.for_create(:create, Map.merge(%{store_id: store.id, title: "X"}, attrs))
    |> Ash.create(authorize?: false)
  end

  describe ":create gate" do
    test "default :physical succeeds against a default store", %{store: store} do
      assert {:ok, product} = create_product(store, %{title: "Item"})
      assert product.product_type == :physical
    end

    test "explicit :physical succeeds against a default store", %{store: store} do
      assert {:ok, product} = create_product(store, %{title: "Item", product_type: :physical})
      assert product.product_type == :physical
    end

    test "rejects a type the store hasn't enabled", %{store: store} do
      assert {:error, %Ash.Error.Invalid{} = err} =
               create_product(store, %{title: "E-book", product_type: :digital_download})

      assert Exception.message(err) =~ "product_type"
    end

    test "succeeds once the store opts into the type", %{store: store} do
      store = enable_type(store, :digital_download)

      assert {:ok, product} =
               create_product(store, %{title: "E-book", product_type: :digital_download})

      assert product.product_type == :digital_download
    end

    test "rejects a previously-disabled type even if the resource one_of allows it",
         %{store: store} do
      # Sanity: the resource accepts :auction at the one_of layer; the gate
      # should still refuse because the store hasn't opted in.
      assert {:error, %Ash.Error.Invalid{}} =
               create_product(store, %{title: "Lot", product_type: :auction})
    end
  end

  describe ":update gate" do
    test "can update other fields without touching product_type", %{store: store} do
      {:ok, product} = create_product(store, %{title: "Item"})

      assert {:ok, updated} =
               product
               |> Ash.Changeset.for_update(:update, %{title: "Renamed"})
               |> Ash.update(authorize?: false)

      assert updated.title == "Renamed"
      assert updated.product_type == :physical
    end

    test "can change product_type to a type the store has enabled", %{store: store} do
      store = enable_type(store, :digital_download)
      {:ok, product} = create_product(store, %{title: "Item"})

      assert {:ok, updated} =
               product
               |> Ash.Changeset.for_update(:update, %{product_type: :digital_download})
               |> Ash.update(authorize?: false)

      assert updated.product_type == :digital_download
    end

    test "refuses to change product_type to a type the store hasn't enabled",
         %{store: store} do
      {:ok, product} = create_product(store, %{title: "Item"})

      assert {:error, %Ash.Error.Invalid{}} =
               product
               |> Ash.Changeset.for_update(:update, %{product_type: :course})
               |> Ash.update(authorize?: false)
    end
  end

  describe "lockstep with Store.accepts?/2" do
    test "every type accepted by the store is allowed; every type refused is blocked",
         %{store: store} do
      # Enable a curated set, then assert the gate matches Store.accepts?/2 for all 7
      enabled = [:physical, :digital_download, :course]

      store =
        store
        |> Ash.Changeset.for_update(:update_settings, %{enabled_product_types: enabled})
        |> Ash.update!(authorize?: false)

      for type <- Emakola.Fulfillment.Dispatcher.supported_types() do
        result = create_product(store, %{title: "P-#{type}", product_type: type})

        if Emakola.Stores.Store.accepts?(store, type) do
          assert {:ok, _} = result, "#{inspect(type)} is enabled but the gate refused it"
        else
          assert {:error, _} = result, "#{inspect(type)} is disabled but the gate allowed it"
        end
      end
    end
  end
end
