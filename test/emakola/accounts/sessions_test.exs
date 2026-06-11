defmodule Emakola.Accounts.SessionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.Sessions

  defp create_staff!(permissions \\ [:manage_stores]) do
    create_user!()
    |> Ash.Changeset.for_update(:set_platform_permissions, %{platform_permissions: permissions})
    |> Ash.update!(authorize?: false)
  end

  defp audit_actions do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
    |> Enum.map(& &1.action)
  end

  describe "create/3" do
    test "creates an active session with ip, user agent, and last_seen_at" do
      user = create_platform_owner!()

      assert {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")

      assert session.user_id == user.id
      assert session.ip == "10.0.0.1"
      assert session.user_agent == "TestAgent/1.0"
      assert session.revoked_at == nil
      assert %DateTime{} = session.last_seen_at
    end
  end

  describe "verify_session_id/1" do
    test "returns the user and session for an active session" do
      user = create_platform_owner!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")

      assert {:ok, verified_user, verified_session} = Sessions.verify_session_id(session.id)
      assert verified_user.id == user.id
      assert verified_session.id == session.id
    end

    test "returns :revoked for a revoked session" do
      user = create_platform_owner!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")
      {:ok, _revoked} = Sessions.revoke(session)

      assert {:error, :revoked} = Sessions.verify_session_id(session.id)
    end

    test "returns :idle_expired for a session idle longer than 24h and revokes it" do
      user = create_platform_owner!()
      stale = DateTime.add(DateTime.utc_now(), -25, :hour)
      session = create_user_session!(user, %{last_seen_at: stale})

      assert {:error, :idle_expired} = Sessions.verify_session_id(session.id)

      # The session is now revoked, not just expired
      assert {:error, :revoked} = Sessions.verify_session_id(session.id)
    end

    test "returns :deactivated for a deactivated user" do
      user = create_staff!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")

      user
      |> Ash.Changeset.for_update(:deactivate_staff, %{})
      |> Ash.update!(authorize?: false)

      assert {:error, :deactivated} = Sessions.verify_session_id(session.id)
    end

    test "returns :not_found for garbage input without raising" do
      assert {:error, :not_found} = Sessions.verify_session_id("not-a-uuid")
      assert {:error, :not_found} = Sessions.verify_session_id("")
      assert {:error, :not_found} = Sessions.verify_session_id(nil)
      assert {:error, :not_found} = Sessions.verify_session_id(123)
    end

    test "returns :not_found for an unknown uuid" do
      assert {:error, :not_found} = Sessions.verify_session_id(Ash.UUID.generate())
    end
  end

  describe "touch/1" do
    test "does not write when last_seen_at is fresh" do
      user = create_platform_owner!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")

      assert {:ok, touched} = Sessions.touch(session)
      assert touched.last_seen_at == session.last_seen_at
    end

    test "updates last_seen_at when older than the touch granularity" do
      user = create_platform_owner!()
      stale = DateTime.add(DateTime.utc_now(), -10, :minute)
      session = create_user_session!(user, %{last_seen_at: stale})

      assert {:ok, touched} = Sessions.touch(session)
      assert DateTime.after?(touched.last_seen_at, stale)
    end
  end

  describe "revoke/1" do
    test "revokes a session struct and writes an audit row" do
      user = create_platform_owner!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")

      assert {:ok, revoked} = Sessions.revoke(session)
      assert %DateTime{} = revoked.revoked_at
      assert :session_revoked in audit_actions()
    end

    test "revokes by session id" do
      user = create_platform_owner!()
      {:ok, session} = Sessions.create(user, "10.0.0.1", "TestAgent/1.0")

      assert {:ok, revoked} = Sessions.revoke(session.id)
      assert %DateTime{} = revoked.revoked_at
    end

    test "returns :not_found for an unknown id" do
      assert {:error, :not_found} = Sessions.revoke(Ash.UUID.generate())
    end
  end

  describe "revoke_all_for_user/1" do
    test "revokes all active sessions, leaves already-revoked rows untouched, and audits" do
      user = create_platform_owner!()
      {:ok, s1} = Sessions.create(user, "10.0.0.1", "A")
      {:ok, s2} = Sessions.create(user, "10.0.0.2", "B")
      {:ok, s3} = Sessions.create(user, "10.0.0.3", "C")
      {:ok, already_revoked} = Sessions.revoke(s3)

      assert {:ok, 2} = Sessions.revoke_all_for_user(user.id)

      assert {:error, :revoked} = Sessions.verify_session_id(s1.id)
      assert {:error, :revoked} = Sessions.verify_session_id(s2.id)

      # Previously revoked session keeps its original revoked_at
      {:ok, reloaded} = Ash.get(Emakola.Accounts.UserSession, s3.id, authorize?: false)
      assert reloaded.revoked_at == already_revoked.revoked_at

      assert :sessions_force_revoked in audit_actions()
    end

    test "does not revoke sessions belonging to other users" do
      user = create_platform_owner!()
      other = create_platform_owner!()
      {:ok, _mine} = Sessions.create(user, "10.0.0.1", "A")
      {:ok, theirs} = Sessions.create(other, "10.0.0.2", "B")

      assert {:ok, 1} = Sessions.revoke_all_for_user(user.id)
      assert {:ok, _user, _session} = Sessions.verify_session_id(theirs.id)
    end
  end

  describe "list_active_for_user/1" do
    test "lists only active sessions for the user, most recently seen first" do
      user = create_platform_owner!()
      other = create_platform_owner!()

      oldest = create_user_session!(user, %{last_seen_at: minutes_ago(3)})
      newest = create_user_session!(user, %{last_seen_at: minutes_ago(1)})
      middle = create_user_session!(user, %{last_seen_at: minutes_ago(2)})
      {:ok, revoked} = Sessions.create(user, "10.0.0.9", "R")
      {:ok, _} = Sessions.revoke(revoked)
      {:ok, _other} = Sessions.create(other, "10.0.0.8", "O")

      assert {:ok, sessions} = Sessions.list_active_for_user(user.id)
      assert Enum.map(sessions, & &1.id) == [newest.id, middle.id, oldest.id]
    end
  end

  defp minutes_ago(minutes), do: DateTime.add(DateTime.utc_now(), -minutes, :minute)
end
