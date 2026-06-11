defmodule Emakola.Accounts.PlatformTeamExtendedTest do
  @moduledoc """
  Phase 8 service-layer tests for Emakola.Accounts.PlatformTeam: staff
  listing, permission editing, deactivation, force logout, invite
  lifecycle, and TOTP reset — including authorization (:unauthorized /
  :owner_required) and last-owner protection.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Swoosh.TestAssertions

  require Ash.Query

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformInvite
  alias Emakola.Accounts.PlatformTeam
  alias Emakola.Accounts.Sessions
  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.User

  defp create_staff!(permissions \\ [:manage_team]) do
    create_user!()
    |> Ash.Changeset.for_update(:set_platform_permissions, %{platform_permissions: permissions})
    |> Ash.update!(authorize?: false)
  end

  defp reload_user!(user), do: Ash.get!(User, user.id, authorize?: false)

  # Factories also emit audit rows (with a nil actor), so scope to the
  # acting user to isolate the event under test.
  defp audit_rows(action, actor) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.Query.filter(action == ^action and actor_id == ^actor.id)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
  end

  # The user factory sends welcome emails — drain them so assertions
  # below only see the invite email.
  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  defp setup_totp!(user) do
    secret = TOTP.generate_secret()

    user
    |> Ash.Changeset.for_update(:setup_totp, %{
      secret: secret,
      code: NimbleTOTP.verification_code(secret)
    })
    |> Ash.update!(authorize?: false)
  end

  describe "list_staff/0" do
    test "returns owners first, excludes plain users" do
      staff = create_staff!([:manage_stores])
      owner = create_platform_owner!()
      plain = create_user!()

      assert {:ok, listed} = PlatformTeam.list_staff()
      ids = Enum.map(listed, & &1.id)

      assert owner.id in ids
      assert staff.id in ids
      refute plain.id in ids

      owner_index = Enum.find_index(listed, &(&1.id == owner.id))
      staff_index = Enum.find_index(listed, &(&1.id == staff.id))
      assert owner_index < staff_index
    end
  end

  describe "update_permissions/3" do
    test "manage_team staff can change another staff member's permissions" do
      actor = create_staff!([:manage_team])
      target = create_staff!([:manage_stores])

      assert {:ok, updated} =
               PlatformTeam.update_permissions(
                 target,
                 %{is_owner: false, platform_permissions: [:manage_merchants]},
                 actor
               )

      assert updated.platform_permissions == [:manage_merchants]
      refute updated.is_owner

      assert [log] = audit_rows(:permissions_changed, actor)
      assert log.metadata["user_id"] == target.id
      assert [] = audit_rows(:owner_changed, actor)
    end

    test "owner promoting a staff member audits :owner_changed too" do
      owner = create_platform_owner!()
      target = create_staff!([:manage_stores])

      assert {:ok, updated} =
               PlatformTeam.update_permissions(
                 target,
                 %{is_owner: true, platform_permissions: [:manage_stores]},
                 owner
               )

      assert updated.is_owner

      assert [_log] = audit_rows(:permissions_changed, owner)
      assert [owner_log] = audit_rows(:owner_changed, owner)
      assert owner_log.metadata["user_id"] == target.id
      assert owner_log.metadata["is_owner"] == true
    end

    test "non-owner cannot change is_owner" do
      actor = create_staff!([:manage_team])
      target = create_staff!([:manage_stores])

      assert {:error, :owner_required} =
               PlatformTeam.update_permissions(
                 target,
                 %{is_owner: true, platform_permissions: [:manage_stores]},
                 actor
               )

      refute reload_user!(target).is_owner
      assert [] = audit_rows(:permissions_changed, actor)
    end

    test "actor without manage_team is rejected" do
      actor = create_staff!([:manage_stores])
      target = create_staff!([:manage_merchants])

      assert {:error, :unauthorized} =
               PlatformTeam.update_permissions(
                 target,
                 %{is_owner: false, platform_permissions: []},
                 actor
               )
    end

    test "demoting the last active owner is rejected" do
      owner = create_platform_owner!()

      assert {:error, %Ash.Error.Invalid{}} =
               PlatformTeam.update_permissions(
                 owner,
                 %{is_owner: false, platform_permissions: [:manage_team]},
                 owner
               )

      assert reload_user!(owner).is_owner
    end
  end

  describe "deactivate/2" do
    test "owner deactivates staff, revokes their sessions, and audits" do
      owner = create_platform_owner!()
      target = create_staff!([:manage_stores])
      create_user_session!(target)

      assert {:ok, deactivated} = PlatformTeam.deactivate(target, owner)

      assert %DateTime{} = deactivated.deactivated_at
      assert {:ok, []} = Sessions.list_active_for_user(target.id)

      assert [log] = audit_rows(:staff_deactivated, owner)
      assert log.metadata["user_id"] == target.id
      assert [_log] = audit_rows(:sessions_force_revoked, target)
    end

    test "non-owner with manage_team gets :owner_required" do
      actor = create_staff!([:manage_team])
      target = create_staff!([:manage_stores])

      assert {:error, :owner_required} = PlatformTeam.deactivate(target, actor)
      assert is_nil(reload_user!(target).deactivated_at)
    end

    test "actor without manage_team gets :unauthorized" do
      actor = create_staff!([:manage_stores])
      target = create_staff!([:manage_merchants])

      assert {:error, :unauthorized} = PlatformTeam.deactivate(target, actor)
    end

    test "deactivating the last active owner is rejected and sessions survive" do
      owner = create_platform_owner!()
      create_user_session!(owner)

      assert {:error, %Ash.Error.Invalid{}} = PlatformTeam.deactivate(owner, owner)

      assert is_nil(reload_user!(owner).deactivated_at)
      assert {:ok, [_session]} = Sessions.list_active_for_user(owner.id)
      assert [] = audit_rows(:staff_deactivated, owner)
    end
  end

  describe "reactivate/2" do
    test "owner reactivates a deactivated staff member and audits" do
      owner = create_platform_owner!()
      target = create_staff!([:manage_stores])
      {:ok, _} = PlatformTeam.deactivate(target, owner)

      assert {:ok, reactivated} = PlatformTeam.reactivate(reload_user!(target), owner)

      assert is_nil(reactivated.deactivated_at)
      assert [log] = audit_rows(:staff_reactivated, owner)
      assert log.metadata["user_id"] == target.id
    end

    test "non-owner gets :owner_required" do
      actor = create_staff!([:manage_team])
      target = create_staff!([:manage_stores])

      assert {:error, :owner_required} = PlatformTeam.reactivate(target, actor)
    end
  end

  describe "force_logout/2" do
    test "revokes all active sessions and returns the count" do
      actor = create_staff!([:manage_team])
      target = create_staff!([:manage_stores])
      create_user_session!(target)
      create_user_session!(target)

      assert {:ok, 2} = PlatformTeam.force_logout(target, actor)
      assert {:ok, []} = Sessions.list_active_for_user(target.id)
      assert [_log] = audit_rows(:sessions_force_revoked, target)
    end

    test "actor without manage_team gets :unauthorized" do
      actor = create_staff!([:manage_stores])
      target = create_staff!([:manage_merchants])
      create_user_session!(target)

      assert {:error, :unauthorized} = PlatformTeam.force_logout(target, actor)
      assert {:ok, [_session]} = Sessions.list_active_for_user(target.id)
    end
  end

  describe "revoke_invite/2" do
    test "revokes an open invite" do
      actor = create_staff!([:manage_team])
      invite = create_platform_invite!()

      assert {:ok, revoked} = PlatformTeam.revoke_invite(invite, actor)
      assert %DateTime{} = revoked.revoked_at
    end

    test "actor without manage_team gets :unauthorized" do
      actor = create_staff!([:manage_stores])
      invite = create_platform_invite!()

      assert {:error, :unauthorized} = PlatformTeam.revoke_invite(invite, actor)
      assert is_nil(Ash.get!(PlatformInvite, invite.id).revoked_at)
    end
  end

  describe "resend_invite/2" do
    test "revokes the old invite and creates a fresh one with the same email and permissions" do
      actor = create_staff!([:manage_team])
      invite = create_platform_invite!(permissions: [:manage_stores])
      flush_emails()

      assert {:ok, new_invite} = PlatformTeam.resend_invite(invite, actor)

      assert new_invite.id != invite.id
      assert new_invite.email == invite.email
      assert new_invite.permissions == [:manage_stores]
      assert %DateTime{} = Ash.get!(PlatformInvite, invite.id).revoked_at

      email = to_string(invite.email)
      assert_email_sent(fn sent -> assert {_, ^email} = hd(sent.to) end)
    end

    test "actor without manage_team gets :unauthorized" do
      actor = create_staff!([:manage_stores])
      invite = create_platform_invite!()

      assert {:error, :unauthorized} = PlatformTeam.resend_invite(invite, actor)
      assert is_nil(Ash.get!(PlatformInvite, invite.id).revoked_at)
    end
  end

  describe "reset_totp/2" do
    test "clears the target's TOTP secret and audits :totp_disabled" do
      actor = create_staff!([:manage_team])
      target = setup_totp!(create_staff!([:manage_stores]))

      assert {:ok, cleared} = PlatformTeam.reset_totp(target, actor)

      assert is_nil(cleared.totp_secret)
      assert is_nil(cleared.totp_last_used_at)
      assert [_log] = audit_rows(:totp_disabled, target)
    end

    test "actor without manage_team gets :unauthorized" do
      actor = create_staff!([:manage_stores])
      target = setup_totp!(create_staff!([:manage_merchants]))

      assert {:error, :unauthorized} = PlatformTeam.reset_totp(target, actor)
      refute is_nil(reload_user!(target).totp_secret)
    end
  end

  describe "create_invite/4 authorization" do
    test "actor without manage_team gets :unauthorized" do
      actor = create_staff!([:manage_stores])

      assert {:error, :unauthorized} =
               PlatformTeam.create_invite(unique_email(), [:manage_stores], actor)
    end
  end
end
