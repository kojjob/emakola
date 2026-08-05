defmodule Emakola.Accounts.SendersTest do
  use Emakola.DataCase, async: false

  import ExUnit.CaptureLog
  import Emakola.Factory

  setup do
    previous_level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: previous_level) end)
  end

  test "magic link sender handles user struct" do
    user = create_user!()
    assert :ok = Emakola.Accounts.Senders.MagicLinkSender.send(user, "test-token", [])
  end

  test "magic link sender handles email string" do
    assert :ok =
             Emakola.Accounts.Senders.MagicLinkSender.send("test@example.com", "test-token", [])
  end

  test "password reset sender handles user struct" do
    user = create_user!()
    assert :ok = Emakola.Accounts.Senders.PasswordResetSender.send(user, "test-token", [])
  end

  test "authentication sender logs mask email addresses and omit tokens" do
    email = "ama.boateng@example.com"
    token = "auth-token-super-secret"
    user = create_user!(email: email)

    log =
      capture_log(fn ->
        assert :ok = Emakola.Accounts.Senders.MagicLinkSender.send(email, token, [])
        assert :ok = Emakola.Accounts.Senders.PasswordResetSender.send(user, token, [])
        assert :ok = Emakola.Accounts.Senders.ConfirmationSender.send(email, token, [])
      end)

    assert log =~ "a***@example.com"
    refute log =~ email
    refute log =~ token
  end
end
