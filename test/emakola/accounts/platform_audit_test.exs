defmodule Emakola.Accounts.PlatformAuditTest do
  use Emakola.DataCase, async: true

  import ExUnit.CaptureLog
  import Emakola.Factory

  alias Emakola.Accounts.PlatformAudit

  describe "log/4" do
    test "with a %User{} actor uses the user's id" do
      user = create_user!()

      assert {:ok, log} = PlatformAudit.log(:sign_in_succeeded, user)

      assert log.actor_id == user.id
      assert log.action == :sign_in_succeeded
      assert log.metadata == %{}
      assert log.ip == nil
    end

    test "with a raw id binary, metadata, and ip" do
      actor_id = Ash.UUID.generate()

      assert {:ok, log} =
               PlatformAudit.log(:permissions_changed, actor_id, %{added: ["stores"]}, "10.0.0.1")

      assert log.actor_id == actor_id
      assert log.metadata == %{"added" => ["stores"]}
      assert log.ip == "10.0.0.1"
    end

    test "with a nil actor" do
      assert {:ok, log} = PlatformAudit.log(:sign_in_failed, nil, %{email: "x@example.com"})

      assert log.actor_id == nil
      assert log.metadata == %{"email" => "x@example.com"}
    end

    test "with an invalid action returns an error tuple and does not raise" do
      log_output =
        capture_log(fn ->
          assert {:error, _} = PlatformAudit.log(:bogus_action, nil)
        end)

      assert log_output =~ "platform audit log failed"
      assert log_output =~ "action="
    end

    test "with an unexpected actor struct logs a warning and uses nil actor_id" do
      merchant = create_merchant!()

      log_output =
        capture_log(fn ->
          assert {:ok, log} = PlatformAudit.log(:sign_in_succeeded, merchant)
          assert log.actor_id == nil
        end)

      assert log_output =~ "unexpected actor"
      assert log_output =~ "treating as nil"
    end
  end
end
