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

    test "accepts a landmark at the 200 char limit" do
      store = create_store!()
      landmark = String.duplicate("a", 200)

      updated =
        store
        |> Ash.Changeset.for_update(:update_settings, %{landmark: landmark})
        |> Ash.update!(authorize?: false)

      assert updated.landmark == landmark
    end

    test "rejects a landmark over 200 chars" do
      store = create_store!()

      assert {:error, %Ash.Error.Invalid{}} =
               store
               |> Ash.Changeset.for_update(:update_settings, %{
                 landmark: String.duplicate("a", 201)
               })
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

    test "does not clobber a fresher digital_address when saving an unrelated field through a stale struct" do
      store =
        create_store!()
        |> Ash.Changeset.for_update(:update_settings, %{digital_address: "GA-100-1000"})
        |> Ash.update!(authorize?: false)

      # Simulates a LiveView that loaded the store before another session
      # (or another tab) wrote a fresher digital_address.
      stale = store

      Ash.Changeset.for_update(store, :update_settings, %{digital_address: "GA-183-8164"})
      |> Ash.update!(authorize?: false)

      # The stale struct's own copy of digital_address ("GA-100-1000") must
      # not be re-persisted just because it saves an unrelated field. The
      # returned struct is built from this changeset's own (stale) `data`
      # merged with its own changes — normal Ecto/Ash behavior, and not
      # what's under test here — so the DB re-fetch below is the real
      # assertion: it proves the SQL UPDATE never touched the column.
      updated =
        stale
        |> Ash.Changeset.for_update(:update_settings, %{name: "Renamed Store"})
        |> Ash.update!(authorize?: false)

      assert updated.name == "Renamed Store"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.digital_address == "GA-183-8164"
    end

    # A discriminating regression test for the fix above. `Ash.Changeset.
    # force_change_attribute/3` skips writing when the forced value equals
    # `changeset.data`'s own current value for that attribute — so when a
    # value is *already normalized* (the only shape a real write can ever
    # persist), re-deriving+force-changing it from the same stale struct is
    # a harmless no-op at the SQL level, even under the old (buggy)
    # `get_attribute`-based implementation. The two-write scenario above
    # therefore passes under both the old and new code and only documents
    # intent. This test plants a *non-canonical* value directly via
    # `Ash.Seed` (bypassing the action layer entirely — simulating a row
    # written before this feature existed, or by a backfill/import script)
    # so normalize/1 actually transforms it into something different from
    # what's on the stale struct, which is what makes the old
    # `get_attribute` implementation force a real, observable write.
    test "does not re-normalize a non-canonical legacy value on a save that doesn't touch it" do
      store = create_store!()

      stale =
        Ash.Seed.update!(store, %{digital_address: "ga 100 1000"}, authorize?: false)

      assert stale.digital_address == "ga 100 1000"

      updated =
        stale
        |> Ash.Changeset.for_update(:update_settings, %{name: "Renamed Store"})
        |> Ash.update!(authorize?: false)

      assert updated.name == "Renamed Store"

      reloaded = Ash.get!(Emakola.Stores.Store, store.id, authorize?: false)
      assert reloaded.digital_address == "ga 100 1000"
    end
  end
end
