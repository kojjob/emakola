defmodule Emakola.Accounts.StorePolicyTest do
  @moduledoc """
  Verifies Store resource authorization policies.

  Critical guarantee: nil-actor (system) callers cannot mutate any store via
  the Ash policy layer. System code must opt in explicitly with
  `authorize?: false`.
  """

  use Emakola.DataCase, async: false

  import Emakola.Factory

  describe "Store update policy" do
    test "denies update with nil actor (no bypass for system writes)" do
      store = create_store!()

      result =
        store
        |> Ash.Changeset.for_update(:update_settings, %{name: "Hacked"})
        |> Ash.update(authorize?: true)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "denies update by a merchant without store membership" do
      store = create_store!()
      stranger = create_merchant!()

      result =
        store
        |> Ash.Changeset.for_update(:update_settings, %{name: "Hacked"})
        |> Ash.update(actor: stranger, authorize?: true)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "allows update by a merchant with store membership" do
      store = create_store!()
      owner = create_merchant!()
      _membership = create_store_membership!(owner, store, :owner)

      result =
        store
        |> Ash.Changeset.for_update(:update_settings, %{name: "New Name"})
        |> Ash.update(actor: owner, authorize?: true)

      assert {:ok, updated} = result
      assert updated.name == "New Name"
    end

    test "allows update with authorize?: false escape hatch (system code path)" do
      store = create_store!()

      result =
        store
        |> Ash.Changeset.for_update(:update_settings, %{name: "System Update"})
        |> Ash.update(authorize?: false)

      assert {:ok, updated} = result
      assert updated.name == "System Update"
    end
  end

  describe "Store create policy" do
    defp create_attrs do
      n = System.unique_integer([:positive])
      %{name: "New Store #{n}", slug: "new-store-#{n}", currency: "GHS"}
    end

    test "denies create with nil actor (no bypass for system creates)" do
      result =
        Emakola.Stores.Store
        |> Ash.Changeset.for_create(:create, create_attrs())
        |> Ash.create(authorize?: true)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "denies create by a customer actor" do
      store = create_store!()
      customer = create_customer!(store)

      result =
        Emakola.Stores.Store
        |> Ash.Changeset.for_create(:create, create_attrs())
        |> Ash.create(actor: customer, authorize?: true)

      assert {:error, %Ash.Error.Forbidden{}} = result
    end

    test "allows create by a merchant actor" do
      merchant = create_merchant!()

      result =
        Emakola.Stores.Store
        |> Ash.Changeset.for_create(:create, create_attrs())
        |> Ash.create(actor: merchant, authorize?: true)

      assert {:ok, _store} = result
    end

    test "allows create with authorize?: false escape hatch (onboarding/system path)" do
      result =
        Emakola.Stores.Store
        |> Ash.Changeset.for_create(:create, create_attrs())
        |> Ash.create(authorize?: false)

      assert {:ok, _store} = result
    end
  end
end
