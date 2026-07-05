defmodule Emakola.Accounts.PlatformInviteTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  require Ash.Query

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.PlatformInvite

  defp audit_entries(action) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
    |> Enum.filter(&(&1.action == action))
  end

  defp pending_by_token_hash(token_hash) do
    PlatformInvite
    |> Ash.Query.for_read(:pending_by_token_hash, %{token_hash: token_hash})
    |> Ash.read_one!()
  end

  describe "create" do
    test "exposes a url-safe raw token via metadata and persists only its sha256 hex" do
      owner = create_platform_owner!()

      invite = create_platform_invite!(invited_by_id: owner.id)
      raw = invite.__metadata__.raw_token

      # 32 random bytes, url-base64 without padding
      assert String.length(raw) == 43
      assert raw =~ ~r/^[A-Za-z0-9_-]+$/

      assert invite.token_hash == :sha256 |> :crypto.hash(raw) |> Base.encode16(case: :lower)
      assert String.length(invite.token_hash) == 64
      assert invite.token_hash =~ ~r/^[0-9a-f]+$/

      # The raw token must never appear in any persisted column
      reloaded = Ash.get!(PlatformInvite, invite.id)

      reloaded
      |> Map.from_struct()
      |> Enum.each(fn {_key, value} ->
        if is_binary(value), do: refute(value =~ raw)
      end)
    end

    test "sets expires_at roughly 7 days out" do
      invite = create_platform_invite!()

      diff = DateTime.diff(invite.expires_at, DateTime.utc_now(), :second)
      assert_in_delta diff, 7 * 24 * 3600, 60
    end

    test "rejects an email with a pending invite" do
      invite = create_platform_invite!()

      assert {:error, %Ash.Error.Invalid{} = error} =
               PlatformInvite
               |> Ash.Changeset.for_create(:create, %{
                 email: to_string(invite.email),
                 invited_by_id: Ash.UUID.generate()
               })
               |> Ash.create()

      assert Exception.message(error) =~ "pending invite"
    end

    test "allows re-inviting an email whose previous invite expired" do
      invite =
        create_platform_invite!(expires_at: DateTime.add(DateTime.utc_now(), -1, :day))

      assert {:ok, _new} =
               PlatformInvite
               |> Ash.Changeset.for_create(:create, %{
                 email: to_string(invite.email),
                 invited_by_id: Ash.UUID.generate()
               })
               |> Ash.create()
    end

    test "rejects an email that already belongs to a user (even deactivated)" do
      user = create_user!()

      assert {:error, %Ash.Error.Invalid{} = error} =
               PlatformInvite
               |> Ash.Changeset.for_create(:create, %{
                 email: to_string(user.email),
                 invited_by_id: Ash.UUID.generate()
               })
               |> Ash.create()

      assert Exception.message(error) =~ "already has an account"

      deactivated =
        user
        |> Ash.Changeset.for_update(:deactivate_staff, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               PlatformInvite
               |> Ash.Changeset.for_create(:create, %{
                 email: to_string(deactivated.email),
                 invited_by_id: Ash.UUID.generate()
               })
               |> Ash.create()
    end

    test "audits :invite_created with the inviter as actor" do
      owner = create_platform_owner!()

      invite =
        create_platform_invite!(
          invited_by_id: owner.id,
          permissions: [:manage_stores]
        )

      assert [entry] = audit_entries(:invite_created)
      assert entry.actor_id == owner.id
      assert entry.metadata["email"] == to_string(invite.email)
      assert entry.metadata["permissions"] == ["manage_stores"]
    end
  end

  describe "pending_by_token_hash" do
    test "returns a pending invite" do
      invite = create_platform_invite!()

      assert %PlatformInvite{id: id} = pending_by_token_hash(invite.token_hash)
      assert id == invite.id
    end

    test "excludes accepted, revoked, and expired invites" do
      accepted = create_platform_invite!()
      accepted |> Ash.Changeset.for_update(:accept, %{}) |> Ash.update!()

      revoked = create_platform_invite!()
      revoked |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!()

      expired =
        create_platform_invite!(expires_at: DateTime.add(DateTime.utc_now(), -1, :day))

      assert pending_by_token_hash(accepted.token_hash) == nil
      assert pending_by_token_hash(revoked.token_hash) == nil
      assert pending_by_token_hash(expired.token_hash) == nil
    end
  end

  describe "accept and revoke" do
    test "accept sets accepted_at and audits :invite_accepted" do
      invite = create_platform_invite!()

      accepted = invite |> Ash.Changeset.for_update(:accept, %{}) |> Ash.update!()

      assert %DateTime{} = accepted.accepted_at
      assert [entry] = audit_entries(:invite_accepted)
      assert entry.metadata["email"] == to_string(invite.email)
    end

    test "revoke sets revoked_at and audits :invite_revoked with the actor" do
      owner = create_platform_owner!()
      invite = create_platform_invite!(invited_by_id: owner.id)

      revoked =
        invite
        |> Ash.Changeset.for_update(:revoke, %{}, actor: owner)
        |> Ash.update!()

      assert %DateTime{} = revoked.revoked_at
      assert [entry] = audit_entries(:invite_revoked)
      assert entry.actor_id == owner.id
      assert entry.metadata["email"] == to_string(invite.email)
    end
  end

  describe "list_open" do
    test "returns unaccepted, unrevoked invites newest first" do
      first = create_platform_invite!()
      second = create_platform_invite!()

      accepted = create_platform_invite!()
      accepted |> Ash.Changeset.for_update(:accept, %{}) |> Ash.update!()

      revoked = create_platform_invite!()
      revoked |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!()

      open =
        PlatformInvite
        |> Ash.Query.for_read(:list_open)
        |> Ash.read!()

      assert Enum.map(open, & &1.id) == [second.id, first.id]
    end
  end
end
