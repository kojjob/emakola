defmodule Emakola.Stores.GhanaDigitalAddressTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  describe "digital_address + landmark" do
    test "defaults to nil for a new store" do
      store = create_store!()
      assert is_nil(store.digital_address)
      assert is_nil(store.landmark)
    end

    test "persists normalized digital address and landmark via the merchant settings action" do
      store = create_store!()

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{
          digital_address: "ga 183 8164",
          landmark: "behind Achimota Melcom"
        })
        |> Ash.update!(authorize?: false)

      assert updated.digital_address == "GA-183-8164"
      assert updated.landmark == "behind Achimota Melcom"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.digital_address == "GA-183-8164"
      assert reloaded.landmark == "behind Achimota Melcom"
    end

    test "rejects an invalid digital address" do
      store = create_store!()

      assert {:error, %Ash.Error.Invalid{}} =
               store
               |> Ash.Changeset.for_update(:update_settings, %{digital_address: "not-a-code"})
               |> Ash.update(authorize?: false)
    end

    test "accepts a blank digital address" do
      store = create_store!()

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{digital_address: ""})
        |> Ash.update!(authorize?: false)

      assert is_nil(updated.digital_address)
    end
  end
end
