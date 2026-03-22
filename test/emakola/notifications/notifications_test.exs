defmodule Emakola.NotificationsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Notifications.{Notification, EmailLog}
  import Emakola.Factory

  describe "Notification" do
    test "creates a notification for a user" do
      user = create_user!()

      assert {:ok, notif} =
               Notification
               |> Ash.Changeset.for_create(:create, %{
                 type: :team_invite,
                 title: "You've been invited",
                 body: "Join the team!",
                 action_url: "/teams/123",
                 user_id: user.id
               })
               |> Ash.create()

      assert notif.type == :team_invite
      assert is_nil(notif.read_at)
    end

    test "marks notification as read" do
      user = create_user!()

      {:ok, notif} =
        Notification
        |> Ash.Changeset.for_create(:create, %{
          type: :system_announcement,
          title: "New feature!",
          user_id: user.id
        })
        |> Ash.create()

      assert {:ok, read_notif} =
               notif
               |> Ash.Changeset.for_update(:mark_read)
               |> Ash.update()

      assert read_notif.read_at
    end
  end

  describe "EmailLog" do
    test "creates an email log entry" do
      user = create_user!()

      assert {:ok, log} =
               EmailLog
               |> Ash.Changeset.for_create(:create, %{
                 to: user.email,
                 subject: "Welcome!",
                 template: "auth/welcome",
                 status: :sent,
                 sent_at: DateTime.utc_now(),
                 user_id: user.id
               })
               |> Ash.create()

      assert log.status == :sent
      assert log.template == "auth/welcome"
    end

    test "marks email as failed" do
      {:ok, log} =
        EmailLog
        |> Ash.Changeset.for_create(:create, %{
          to: "test@example.com",
          subject: "Test",
          template: "test",
          status: :pending
        })
        |> Ash.create()

      assert {:ok, failed} =
               log
               |> Ash.Changeset.for_update(:mark_failed, %{error: "SMTP connection refused"})
               |> Ash.update()

      assert failed.status == :failed
      assert failed.error == "SMTP connection refused"
    end
  end

  describe "PubSub broadcast" do
    test "broadcasts notification to user channel" do
      Phoenix.PubSub.subscribe(Emakola.PubSub, "user_notifications:test-user-id")

      Emakola.Notifications.broadcast_to_user("test-user-id", %{
        type: :team_invite,
        title: "Test"
      })

      assert_receive {:new_notification, %{type: :team_invite}}
    end
  end
end
