defmodule Emakola.Accounts.UserTotpActionsTest do
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Accounts.PlatformAuditLog
  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.User

  require Ash.Query

  defp setup_totp(user, secret, code) do
    user
    |> Ash.Changeset.for_update(:setup_totp, %{secret: secret, code: code})
    |> Ash.update(authorize?: false)
  end

  defp setup_totp!(user) do
    secret = TOTP.generate_secret()

    {:ok, user} = setup_totp(user, secret, NimbleTOTP.verification_code(secret))
    user
  end

  defp audit_rows(user, action) do
    PlatformAuditLog
    |> Ash.Query.for_read(:list)
    |> Ash.Query.filter(action == ^action and actor_id == ^user.id)
    |> Ash.read!(authorize?: false)
    |> Map.fetch!(:results)
  end

  describe "update :setup_totp" do
    test "with a valid code persists secret + last-used and audits :totp_enabled" do
      user = create_user!()
      secret = TOTP.generate_secret()

      assert {:ok, updated} = setup_totp(user, secret, NimbleTOTP.verification_code(secret))

      assert updated.totp_secret == secret
      assert %DateTime{} = updated.totp_last_used_at
      assert [_log] = audit_rows(user, :totp_enabled)
    end

    test "with an invalid code errors and does not set the secret" do
      user = create_user!()
      secret = TOTP.generate_secret()

      assert {:error, %Ash.Error.Invalid{}} = setup_totp(user, secret, "000000")

      reloaded = Ash.get!(User, user.id, authorize?: false)
      assert is_nil(reloaded.totp_secret)
      assert is_nil(reloaded.totp_last_used_at)
      assert [] = audit_rows(user, :totp_enabled)
    end
  end

  describe "update :record_totp_use" do
    test "bumps totp_last_used_at" do
      user = setup_totp!(create_user!())
      previous = user.totp_last_used_at

      bumped =
        user
        |> Ash.Changeset.for_update(:record_totp_use, %{})
        |> Ash.update!(authorize?: false)

      assert DateTime.compare(bumped.totp_last_used_at, previous) == :gt
    end
  end

  describe "update :clear_totp" do
    test "clears totp_secret and totp_last_used_at" do
      user = setup_totp!(create_user!())

      cleared =
        user
        |> Ash.Changeset.for_update(:clear_totp, %{})
        |> Ash.update!(authorize?: false)

      assert is_nil(cleared.totp_secret)
      assert is_nil(cleared.totp_last_used_at)
    end
  end
end
