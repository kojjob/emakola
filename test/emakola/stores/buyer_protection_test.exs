defmodule Emakola.Stores.BuyerProtectionTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  describe "buyer_protection_enabled" do
    test "defaults to false for a new store" do
      store = create_store!()
      refute store.buyer_protection_enabled
    end

    test "persists via the merchant settings action" do
      store = create_store!()

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
        |> Ash.update!(authorize?: false)

      assert updated.buyer_protection_enabled == true

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.buyer_protection_enabled == true
    end

    test "can be turned back off" do
      store = create_store!()

      on =
        store
        |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
        |> Ash.update!(authorize?: false)

      off =
        on
        |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: false})
        |> Ash.update!(authorize?: false)

      refute off.buyer_protection_enabled
    end
  end
end
