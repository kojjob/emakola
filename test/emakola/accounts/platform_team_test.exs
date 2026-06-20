defmodule Emakola.Accounts.PlatformTeamTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory
  import Swoosh.TestAssertions

  require Ash.Query

  alias Emakola.Accounts.PlatformInvite
  alias Emakola.Accounts.PlatformTeam
  alias Emakola.Accounts.User

  defmodule FailingMailer do
    def invite(_email, _raw_token, _inviter_name), do: {:error, :connection_refused}
  end

  @password "Password123!"

  defp reload_invite(invite), do: Ash.get!(PlatformInvite, invite.id)

  defp get_user_by_email(email) do
    User
    |> Ash.Query.filter(email == ^email)
    |> Ash.read_one!(authorize?: false)
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

  describe "create_invite/3" do
    test "creates the invite and emails the raw token link" do
      owner = create_platform_owner!()
      email = unique_email()
      flush_emails()

      assert {:ok, invite} = PlatformTeam.create_invite(email, [:manage_stores], owner)

      assert to_string(invite.email) == email
      assert invite.permissions == [:manage_stores]
      assert invite.invited_by_id == owner.id

      raw = invite.__metadata__.raw_token

      assert_email_sent(fn sent ->
        assert {_, ^email} = hd(sent.to)
        assert sent.subject =~ "invited to the Makola platform team"
        assert sent.html_body =~ "/platform/invite/accept/#{raw}"
        assert sent.text_body =~ "/platform/invite/accept/#{raw}"
      end)
    end

    test "requires an actor" do
      assert {:error, :actor_required} = PlatformTeam.create_invite(unique_email(), [], nil)
    end

    test "revokes the invite and returns :email_delivery_failed when mailer fails" do
      owner = create_platform_owner!()
      email = unique_email()
      flush_emails()

      assert {:error, :email_delivery_failed} =
               PlatformTeam.create_invite(email, [], owner, mailer: FailingMailer)

      assert_no_email_sent()

      invite =
        PlatformInvite
        |> Ash.Query.filter(email == ^email)
        |> Ash.read_one!(authorize?: false)

      assert %DateTime{} = invite.revoked_at
    end

    test "returns validation errors without sending an email" do
      owner = create_platform_owner!()
      user = create_user!()
      flush_emails()

      assert {:error, %Ash.Error.Invalid{}} =
               PlatformTeam.create_invite(to_string(user.email), [], owner)

      assert_no_email_sent()
    end
  end

  describe "accept_invite/2" do
    setup do
      owner = create_platform_owner!()

      {:ok, invite} =
        PlatformTeam.create_invite(unique_email(), [:manage_stores], owner)

      %{owner: owner, invite: invite, raw: invite.__metadata__.raw_token}
    end

    test "creates a confirmed staff user and marks the invite accepted",
         %{invite: invite, raw: raw} do
      assert {:ok, user} =
               PlatformTeam.accept_invite(raw, %{
                 name: "New Staff",
                 password: @password,
                 password_confirmation: @password
               })

      assert to_string(user.email) == to_string(invite.email)
      assert user.name == "New Staff"
      assert %DateTime{} = user.confirmed_at
      assert user.platform_permissions == [:manage_stores]
      refute user.is_owner
      assert Bcrypt.verify_pass(@password, user.hashed_password)

      assert %DateTime{} = reload_invite(invite).accepted_at
    end

    test "returns :invalid for an unknown token" do
      assert {:error, :invalid} =
               PlatformTeam.accept_invite("no-such-token", %{
                 name: "X",
                 password: @password,
                 password_confirmation: @password
               })
    end

    test "returns :expired for an expired invite" do
      invite =
        create_platform_invite!(expires_at: DateTime.add(DateTime.utc_now(), -1, :day))

      assert {:error, :expired} =
               PlatformTeam.accept_invite(invite.__metadata__.raw_token, %{
                 name: "X",
                 password: @password,
                 password_confirmation: @password
               })
    end

    test "returns :already_accepted for a used invite", %{raw: raw} do
      assert {:ok, _user} =
               PlatformTeam.accept_invite(raw, %{
                 name: "First",
                 password: @password,
                 password_confirmation: @password
               })

      assert {:error, :already_accepted} =
               PlatformTeam.accept_invite(raw, %{
                 name: "Second",
                 password: @password,
                 password_confirmation: @password
               })
    end

    test "returns :revoked for a revoked invite", %{invite: invite, raw: raw} do
      invite |> Ash.Changeset.for_update(:revoke, %{}) |> Ash.update!()

      assert {:error, :revoked} =
               PlatformTeam.accept_invite(raw, %{
                 name: "X",
                 password: @password,
                 password_confirmation: @password
               })
    end

    test "returns :email_taken and rolls back when the email was registered after the invite",
         %{invite: invite, raw: raw} do
      create_user!(email: to_string(invite.email))

      assert {:error, :email_taken} =
               PlatformTeam.accept_invite(raw, %{
                 name: "Late",
                 password: @password,
                 password_confirmation: @password
               })

      # Transactional: the invite must NOT have been marked accepted
      assert reload_invite(invite).accepted_at == nil
    end

    test "a user-create validation failure leaves the invite pending",
         %{invite: invite, raw: raw} do
      assert {:error, %Ash.Error.Invalid{}} =
               PlatformTeam.accept_invite(raw, %{
                 name: "Weak",
                 password: "short",
                 password_confirmation: "short"
               })

      assert reload_invite(invite).accepted_at == nil
      assert get_user_by_email(to_string(invite.email)) == nil
    end
  end
end
