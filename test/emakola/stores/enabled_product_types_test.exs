defmodule Emakola.Stores.EnabledProductTypesTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Fulfillment.Dispatcher
  alias Emakola.Stores.Store

  describe "default" do
    test "new stores enable only :physical by default" do
      store = create_store!()
      assert store.enabled_product_types == [:physical]
    end
  end

  describe "update via :update_settings" do
    test "can opt into multiple product types" do
      store = create_store!()

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{
          enabled_product_types: [:physical, :digital_download, :course]
        })
        |> Ash.update!(authorize?: false)

      assert updated.enabled_product_types == [:physical, :digital_download, :course]
    end

    test "can disable physical (a store that only sells digital is valid)" do
      store = create_store!()

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{
          enabled_product_types: [:digital_download]
        })
        |> Ash.update!(authorize?: false)

      assert updated.enabled_product_types == [:digital_download]
    end

    test "rejects an unknown product_type in the list" do
      store = create_store!()

      assert {:error, _} =
               store
               |> Ash.Changeset.for_update(:update_settings, %{
                 enabled_product_types: [:physical, :not_a_real_type]
               })
               |> Ash.update(authorize?: false)
    end

    test "rejects nil — every store must declare what it sells" do
      store = create_store!()

      assert {:error, _} =
               store
               |> Ash.Changeset.for_update(:update_settings, %{enabled_product_types: nil})
               |> Ash.update(authorize?: false)
    end
  end

  describe "accepts?/2" do
    test "returns true when the type is in enabled_product_types" do
      store = create_store!()
      assert Store.accepts?(store, :physical)
    end

    test "returns false when the type is not in enabled_product_types" do
      store = create_store!()
      refute Store.accepts?(store, :digital_download)
    end

    test "works for every dispatcher-supported type when enabled" do
      store = create_store!()

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{
          enabled_product_types: Dispatcher.supported_types()
        })
        |> Ash.update!(authorize?: false)

      for type <- Dispatcher.supported_types() do
        assert Store.accepts?(updated, type), "expected store to accept #{inspect(type)}"
      end
    end

    test "returns false for an unknown product_type" do
      store = create_store!()
      refute Store.accepts?(store, :not_a_real_type)
    end
  end

  describe "lockstep with Dispatcher.supported_types/0" do
    test "every supported_types atom is acceptable in enabled_product_types" do
      store = create_store!()

      assert {:ok, updated} =
               store
               |> Ash.Changeset.for_update(:update_settings, %{
                 enabled_product_types: Dispatcher.supported_types()
               })
               |> Ash.update(authorize?: false)

      assert MapSet.new(updated.enabled_product_types) ==
               MapSet.new(Dispatcher.supported_types())
    end
  end
end
