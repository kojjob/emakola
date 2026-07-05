defmodule Emakola.Accounts.PlatformAuditLogTest do
  use Emakola.DataCase, async: true

  alias Emakola.Accounts.PlatformAuditLog

  defp create_log!(attrs) do
    PlatformAuditLog
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  describe "create" do
    test "persists a log entry with full attributes" do
      actor_id = Ash.UUID.generate()

      log =
        create_log!(%{
          actor_id: actor_id,
          action: :sign_in_succeeded,
          metadata: %{email: "staff@example.com"},
          ip: "41.66.200.1"
        })

      assert log.actor_id == actor_id
      assert log.action == :sign_in_succeeded
      assert log.metadata == %{"email" => "staff@example.com"}
      assert log.ip == "41.66.200.1"
      assert log.inserted_at
    end

    test "actor_id is nullable" do
      log = create_log!(%{actor_id: nil, action: :sign_in_failed})

      assert log.actor_id == nil
    end

    test "rejects an action outside the allowed set" do
      assert {:error, %Ash.Error.Invalid{}} =
               PlatformAuditLog
               |> Ash.Changeset.for_create(:create, %{action: :not_a_real_action})
               |> Ash.create(authorize?: false)
    end

    test "metadata defaults to an empty map" do
      log = create_log!(%{action: :sign_out})

      assert log.metadata == %{}
    end
  end

  describe "append-only" do
    test "defines no update or destroy actions" do
      assert PlatformAuditLog
             |> Ash.Resource.Info.actions()
             |> Enum.filter(&(&1.type in [:update, :destroy])) == []
    end
  end

  describe "store lifecycle actions" do
    test "accepts the four store lifecycle actions" do
      for action <- [:store_suspended, :store_blocked, :store_archived, :store_reactivated] do
        assert %{action: ^action} = create_log!(%{action: action})
      end
    end
  end

  describe "list_for_store" do
    test "returns only the given store's lifecycle entries, newest-first" do
      store_a = Ash.UUID.generate()
      store_b = Ash.UUID.generate()

      create_log!(%{
        action: :store_suspended,
        metadata: %{"store_id" => store_a, "reason" => "1"}
      })

      create_log!(%{action: :store_reactivated, metadata: %{"store_id" => store_a}})
      create_log!(%{action: :store_blocked, metadata: %{"store_id" => store_b}})

      entries =
        PlatformAuditLog
        |> Ash.Query.for_read(:list_for_store, %{store_id: store_a})
        |> Ash.read!(authorize?: false)

      assert length(entries) == 2
      assert Enum.all?(entries, &(&1.metadata["store_id"] == store_a))
      actions = Enum.map(entries, & &1.action)
      assert :store_suspended in actions
      assert :store_reactivated in actions
    end
  end

  describe "list" do
    test "returns newest-first and paginates with keyset cursors" do
      for n <- 1..3 do
        create_log!(%{action: :sign_out, metadata: %{seq: n}})
      end

      assert {:ok, %Ash.Page.Keyset{results: [first, second] = results}} =
               PlatformAuditLog
               |> Ash.Query.for_read(:list)
               |> Ash.read(page: [limit: 2], authorize?: false)

      assert first.metadata == %{"seq" => 3}
      assert second.metadata == %{"seq" => 2}

      cursor = List.last(results).__metadata__.keyset

      assert {:ok, %Ash.Page.Keyset{results: [third]}} =
               PlatformAuditLog
               |> Ash.Query.for_read(:list)
               |> Ash.read(page: [limit: 2, after: cursor], authorize?: false)

      assert third.metadata == %{"seq" => 1}
    end
  end
end
