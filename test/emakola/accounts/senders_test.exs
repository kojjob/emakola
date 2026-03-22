defmodule Emakola.Accounts.SendersTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory

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
end
