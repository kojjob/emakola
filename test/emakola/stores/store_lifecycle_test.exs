defmodule Emakola.Stores.StoreLifecycleTest do
  @moduledoc """
  Platform-owned store lifecycle. The `status` field is the platform's control
  (active/suspended/blocked/archived); the merchant-owned `active` flag is the
  merchant's own open/closed switch. A store is publicly live only when BOTH
  say so: `active == true and status == :active`.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Stores
  alias Emakola.Stores.Store

  describe "status attribute" do
    test "a newly created store defaults to :active with no reason or timestamp" do
      store = Factory.create_store!()
      assert store.status == :active
      assert is_nil(store.status_reason)
      assert is_nil(store.status_changed_at)
    end
  end

  describe "live?/1" do
    test "an active store with :active status is live" do
      assert Store.live?(%Store{active: true, status: :active})
    end

    test "a merchant-deactivated store is not live" do
      refute Store.live?(%Store{active: false, status: :active})
    end

    test "suspended, blocked, and archived stores are not live" do
      refute Store.live?(%Store{active: true, status: :suspended})
      refute Store.live?(%Store{active: true, status: :blocked})
      refute Store.live?(%Store{active: true, status: :archived})
    end
  end

  # ── Lifecycle actions (Task #2) ──

  describe "suspend/block/archive/reactivate actions" do
    setup do
      %{store: Factory.create_store!()}
    end

    test ":suspend sets status, reason, and stamps changed_at", %{store: store} do
      assert {:ok, suspended} =
               Stores.suspend_store(store, %{reason: "Chargeback investigation"},
                 authorize?: false
               )

      assert suspended.status == :suspended
      assert suspended.status_reason == "Chargeback investigation"
      assert %DateTime{} = suspended.status_changed_at
    end

    test ":suspend requires a reason", %{store: store} do
      assert {:error, _} = Stores.suspend_store(store, %{}, authorize?: false)
    end

    test ":block sets status to :blocked with a reason", %{store: store} do
      assert {:ok, blocked} =
               Stores.block_store(store, %{reason: "Selling counterfeit goods"},
                 authorize?: false
               )

      assert blocked.status == :blocked
      assert blocked.status_reason == "Selling counterfeit goods"
      assert %DateTime{} = blocked.status_changed_at
    end

    test ":block requires a reason", %{store: store} do
      assert {:error, _} = Stores.block_store(store, %{}, authorize?: false)
    end

    test ":archive sets status to :archived; reason is optional", %{store: store} do
      assert {:ok, archived} = Stores.archive_store(store, %{}, authorize?: false)
      assert archived.status == :archived
      assert %DateTime{} = archived.status_changed_at
    end

    test ":reactivate restores :active and clears the reason from any state", %{store: store} do
      for action <- [:suspend_store, :block_store, :archive_store] do
        {:ok, non_active} = apply(Stores, action, [store, %{reason: "x"}, [authorize?: false]])
        refute non_active.status == :active

        assert {:ok, reactivated} =
                 Stores.reactivate_store(non_active, %{}, authorize?: false)

        assert reactivated.status == :active
        assert is_nil(reactivated.status_reason)
      end
    end

    test "re-suspending an already-suspended store is idempotent and updates the reason", %{
      store: store
    } do
      {:ok, first} = Stores.suspend_store(store, %{reason: "first"}, authorize?: false)
      {:ok, second} = Stores.suspend_store(first, %{reason: "second"}, authorize?: false)
      assert second.status == :suspended
      assert second.status_reason == "second"
    end
  end

  # ── Directory visibility (Task #3) ──

  describe "public directory reads exclude non-live stores" do
    setup do
      # Featured + ranked so each store qualifies for every directory read.
      meta = %{featured: true, featured_rank: 1}
      live = Factory.create_store!(meta)

      {:ok, suspended} =
        Stores.suspend_store(Factory.create_store!(meta), %{reason: "x"}, authorize?: false)

      {:ok, blocked} =
        Stores.block_store(Factory.create_store!(meta), %{reason: "x"}, authorize?: false)

      {:ok, archived} = Stores.archive_store(Factory.create_store!(meta), %{}, authorize?: false)
      %{live: live, suspended: suspended, blocked: blocked, archived: archived}
    end

    defp read_ids(query) do
      case Ash.read!(query, authorize?: false) do
        %{results: results} -> results
        list when is_list(list) -> list
      end
      |> Enum.map(& &1.id)
    end

    for action <- [
          :list_active,
          :list_recent,
          :list_featured,
          :list_editor_picks,
          :list_with_filters
        ] do
      test "#{action} shows live, hides suspended/blocked/archived", ctx do
        ids = Store |> Ash.Query.for_read(unquote(action)) |> read_ids()
        assert ctx.live.id in ids
        refute ctx.suspended.id in ids
        refute ctx.blocked.id in ids
        refute ctx.archived.id in ids
      end
    end

    test "list_by_slugs shows live, hides non-live", ctx do
      slugs = Enum.map([ctx.live, ctx.suspended, ctx.blocked, ctx.archived], & &1.slug)
      ids = slugs |> Stores.list_stores_by_slugs!(authorize?: false) |> Enum.map(& &1.id)
      assert ctx.live.id in ids
      refute ctx.suspended.id in ids
      refute ctx.archived.id in ids
    end

    test "list_for_admin still includes every store regardless of status", ctx do
      ids = Stores.list_stores_for_admin!("", authorize?: false) |> Enum.map(& &1.id)
      assert ctx.live.id in ids
      assert ctx.suspended.id in ids
      assert ctx.blocked.id in ids
      assert ctx.archived.id in ids
    end
  end

  # ── Lifecycle actions are platform-only (Task #6) ──

  describe "lifecycle actions are platform-only" do
    test "a merchant actor cannot reactivate their own suspended store" do
      {merchant, store} = Factory.create_merchant_with_store!()
      {:ok, suspended} = Stores.suspend_store(store, %{reason: "x"}, authorize?: false)

      assert {:error, _} =
               Stores.reactivate_store(suspended, %{}, actor: merchant, authorize?: true)
    end

    test "a merchant actor cannot suspend a store" do
      {merchant, store} = Factory.create_merchant_with_store!()

      assert {:error, _} =
               Stores.suspend_store(store, %{reason: "x"}, actor: merchant, authorize?: true)
    end

    test "the platform reactivates via authorize?: false" do
      {:ok, suspended} =
        Stores.suspend_store(Factory.create_store!(), %{reason: "x"}, authorize?: false)

      assert {:ok, reactivated} = Stores.reactivate_store(suspended, %{}, authorize?: false)
      assert reactivated.status == :active
    end
  end
end
