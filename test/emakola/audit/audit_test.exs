defmodule Emakola.AuditTest do
  use Emakola.DataCase, async: true

  alias Emakola.Audit
  alias Emakola.Audit.AuditLog
  import Emakola.Factory

  describe "AuditLog creation" do
    test "creates an audit log entry with all fields" do
      user = create_user!()
      org = create_organisation!()

      assert {:ok, log} =
               Audit.log(:create, "User", user.id, user.id, org.id,
                 changes: %{email: "new@test.com"},
                 ip_address: "127.0.0.1",
                 user_agent: "Test/1.0"
               )

      assert log.action == :create
      assert log.resource_type == "User"
      assert log.resource_id == user.id
      assert log.actor_id == user.id
      assert log.organisation_id == org.id
      assert log.changes == %{"email" => "new@test.com"}
      assert log.ip_address == "127.0.0.1"
      assert log.user_agent == "Test/1.0"
      assert log.inserted_at
    end

    test "creates log without optional fields" do
      assert {:ok, log} =
               Audit.log(:login, "Session", "sess-123", nil, nil)

      assert log.action == :login
      assert log.resource_type == "Session"
      assert log.resource_id == "sess-123"
      assert is_nil(log.actor_id)
      assert is_nil(log.organisation_id)
      assert log.changes == %{}
      assert log.metadata == %{}
      assert is_nil(log.ip_address)
      assert is_nil(log.user_agent)
    end

    test "creates log for each valid action type" do
      valid_actions = [
        :create,
        :update,
        :delete,
        :login,
        :logout,
        :invite,
        :role_change,
        :subscription_change,
        :api_key_created,
        :api_key_revoked,
        :settings_changed,
        :export_requested
      ]

      for action <- valid_actions do
        assert {:ok, log} = Audit.log(action, "Resource", "id-#{action}", nil, nil)
        assert log.action == action
      end
    end

    test "rejects invalid action" do
      assert {:error, _} =
               AuditLog
               |> Ash.Changeset.for_create(:create, %{
                 action: :nonexistent_action,
                 resource_type: "User",
                 resource_id: "123"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires resource_type" do
      assert {:error, _} =
               AuditLog
               |> Ash.Changeset.for_create(:create, %{
                 action: :create,
                 resource_id: "123"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires resource_id" do
      assert {:error, _} =
               AuditLog
               |> Ash.Changeset.for_create(:create, %{
                 action: :create,
                 resource_type: "User"
               })
               |> Ash.create(authorize?: false)
    end

    test "requires action" do
      assert {:error, _} =
               AuditLog
               |> Ash.Changeset.for_create(:create, %{
                 resource_type: "User",
                 resource_id: "123"
               })
               |> Ash.create(authorize?: false)
    end
  end

  describe "AuditLog querying" do
    test "list_logs returns all logs" do
      Audit.log(:create, "User", "1", nil, nil)
      Audit.log(:update, "User", "2", nil, nil)

      {:ok, logs} = Audit.list_logs()
      assert length(logs) >= 2
    end

    test "filters by resource type and id" do
      user = create_user!()
      Audit.log(:create, "User", user.id, user.id, nil)
      Audit.log(:update, "User", user.id, user.id, nil)
      Audit.log(:create, "Agent", "other-id", user.id, nil)

      {:ok, logs} = Audit.list_by_resource("User", user.id)
      assert length(logs) == 2
      assert Enum.all?(logs, &(&1.resource_type == "User"))
      assert Enum.all?(logs, &(&1.resource_id == user.id))
    end

    test "filters by actor" do
      user = create_user!()
      other = create_user!()
      Audit.log(:create, "User", "1", user.id, nil)
      Audit.log(:update, "User", "2", user.id, nil)
      Audit.log(:create, "User", "3", other.id, nil)

      {:ok, logs} = Audit.list_by_actor(user.id)
      assert length(logs) == 2
      assert Enum.all?(logs, &(&1.actor_id == user.id))
    end

    test "returns empty list for no matches" do
      {:ok, logs} = Audit.list_by_resource("NonExistent", "none")
      assert logs == []
    end

    test "returns empty list for unknown actor" do
      {:ok, logs} = Audit.list_by_actor(Ash.UUID.generate())
      assert logs == []
    end
  end

  describe "immutability" do
    test "audit logs have no update or destroy actions" do
      actions = Ash.Resource.Info.actions(AuditLog)
      action_types = Enum.map(actions, & &1.type)
      refute :update in action_types
      refute :destroy in action_types
    end
  end

  describe "edge cases" do
    test "handles very large changes map" do
      large_changes = Map.new(1..100, fn i -> {"field_#{i}", "value_#{i}"} end)

      assert {:ok, log} =
               Audit.log(:update, "User", "123", nil, nil, changes: large_changes)

      assert map_size(log.changes) == 100
    end

    test "handles unicode in metadata" do
      assert {:ok, log} =
               Audit.log(:create, "User", "123", nil, nil,
                 metadata: %{"name" => "Unicode Test 日本語"}
               )

      assert log.metadata["name"] == "Unicode Test 日本語"
    end

    test "handles empty strings for ip_address and user_agent" do
      assert {:ok, log} =
               Audit.log(:login, "Session", "s1", nil, nil,
                 ip_address: "",
                 user_agent: ""
               )

      # Empty strings may be stored as nil depending on DB adapter
      assert log.ip_address in ["", nil]
      assert log.user_agent in ["", nil]
    end

    test "handles concurrent audit log creation" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            Audit.log(:create, "User", "#{i}", nil, nil)
          end)
        end

      results = Task.await_many(tasks)

      assert Enum.all?(results, fn
               {:ok, _} -> true
               _ -> false
             end)

      {:ok, all_logs} = Audit.list_logs()
      created_ids = Enum.map(all_logs, & &1.resource_id)
      for i <- 1..20, do: assert("#{i}" in created_ids)
    end

    test "handles deeply nested metadata" do
      nested = %{"level1" => %{"level2" => %{"level3" => "deep_value"}}}

      assert {:ok, log} =
               Audit.log(:update, "Config", "cfg-1", nil, nil, metadata: nested)

      assert get_in(log.metadata, ["level1", "level2", "level3"]) == "deep_value"
    end
  end
end
