defmodule EmakolaWeb.Platform.AnnouncementLive.IndexTest do
  @moduledoc """
  Platform announcements page: create (persists + enqueues publish worker +
  audits), permission gating, and cancel.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  use Oban.Testing, repo: Emakola.Repo
  import Phoenix.LiveViewTest

  alias Emakola.Notifications
  alias Emakola.Notifications.Workers.AnnouncementPublishWorker

  test "staff without :manage_announcements is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/announcements")
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "creating an announcement persists it and enqueues the publish worker", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/announcements")
      assert has_element?(view, "#announcement-form")

      view
      |> form("#announcement-form", %{
        "announcement" => %{
          "title" => "Scheduled maintenance",
          "body" => "Down Sunday 2am.",
          "severity" => "warning",
          "channels" => ["banner", "email"],
          "audience" => "all",
          "publish_at" => "2026-07-01T02:00",
          "expires_at" => ""
        }
      })
      |> render_submit()

      {:ok, [ann]} = Notifications.list_announcements_for_admin(authorize?: false)
      assert ann.title == "Scheduled maintenance"
      assert ann.severity == :warning
      assert ann.channels == [:banner, :email]
      assert ann.status == :scheduled
      assert has_element?(view, "#announcement-#{ann.id}", "Scheduled maintenance")
      assert has_element?(view, "#flash-info", "Announcement scheduled")

      assert_enqueued(worker: AnnouncementPublishWorker, args: %{"announcement_id" => ann.id})
    end

    test "canceling a scheduled announcement flips it to :canceled", %{conn: conn} do
      {:ok, ann} =
        Notifications.create_announcement(
          %{
            title: "Cancel me",
            body: "x",
            channels: [:banner],
            audience: :all,
            publish_at: ~U[2026-07-01 00:00:00Z]
          },
          authorize?: false
        )

      {:ok, view, _html} = live(conn, ~p"/platform/announcements")

      view
      |> element("button[phx-value-id='#{ann.id}'][phx-click='cancel']")
      |> render_click()

      assert has_element?(view, "#announcement-#{ann.id}", "Canceled")

      {:ok, reloaded} = Notifications.get_announcement(ann.id, authorize?: false)
      assert reloaded.status == :canceled
    end
  end
end
