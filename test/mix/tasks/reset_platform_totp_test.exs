defmodule Mix.Tasks.Emakola.ResetPlatformTotpTest do
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Accounts.TOTP
  alias Emakola.Accounts.User

  setup do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    :ok
  end

  test "clears TOTP enrolment for an existing user" do
    secret = TOTP.generate_secret()

    user =
      create_user!()
      |> Ash.Changeset.for_update(:setup_totp, %{
        secret: secret,
        code: NimbleTOTP.verification_code(secret)
      })
      |> Ash.update!(authorize?: false)

    Mix.Tasks.Emakola.ResetPlatformTotp.reset(to_string(user.email))

    reloaded = Ash.get!(User, user.id, authorize?: false)
    assert is_nil(reloaded.totp_secret)
    assert is_nil(reloaded.totp_last_used_at)
    assert_received {:mix_shell, :info, [msg]}
    assert msg =~ "TOTP reset"
  end

  test "errors clearly for an unknown email" do
    Mix.Tasks.Emakola.ResetPlatformTotp.reset("missing@example.com")

    assert_received {:mix_shell, :error, [msg]}
    assert msg =~ "No user found"
  end

  test "errors without exactly one email argument" do
    Mix.Tasks.Emakola.ResetPlatformTotp.run([])

    assert_received {:mix_shell, :error, [msg]}
    assert msg =~ "Usage"
  end
end
