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
