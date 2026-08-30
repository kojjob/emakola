defmodule EmakolaWeb.Platform.NotificationBellTest do
  @moduledoc """
  The staff bell.

  The platform topbar has always drawn a bell. It was a bare `<button>` with
  no badge, no panel and no handler — a control that looks like it does
  something and does nothing, which is the one thing the project guardrails
  rule out. Staff were the only actor who could own a notification and had
  nowhere to see it.
  """
  use EmakolaWeb.ConnCase, async: true
  use Emakola.LiveViewHelpers

  alias Emakola.Notifications

  setup %{conn: conn} do
    {conn, user, _session} = setup_platform_staff(conn)
    %{conn: conn, user: user}
  end

  test "a staff notification appears in the bell", ctx do
    {:ok, _} = Notifications.notify(ctx.user, :system, %{title: "Nightly backup finished"})

    {:ok, _view, html} = live(ctx.conn, ~p"/platform")

    assert html =~ "Nightly backup finished"
  end

  test "another staff member's notification stays out", ctx do
    other = Emakola.Factory.create_platform_owner!()
    {:ok, _} = Notifications.notify(other, :system, %{title: "Not for you"})

    {:ok, _view, html} = live(ctx.conn, ~p"/platform")

    refute html =~ "Not for you"
  end

  test "the bell shows a count when something is unread", ctx do
    {:ok, _} = Notifications.notify(ctx.user, :system, %{title: "One"})
    {:ok, _} = Notifications.notify(ctx.user, :system, %{title: "Two"})

    {:ok, _view, html} = live(ctx.conn, ~p"/platform")

    assert html =~ ~s(data-role="notification-count")
    assert html =~ "2"
  end

  test "no count when nothing is unread", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/platform")

    refute html =~ ~s(data-role="notification-count")
  end

  test "an arrival appears without a refresh", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/platform")

    {:ok, _} = Notifications.notify(ctx.user, :verification_result, %{title: "Shop verified"})

    assert render(view) =~ "Shop verified"
  end

  test "marking all read clears the count", ctx do
    {:ok, _} = Notifications.notify(ctx.user, :system, %{title: "One"})

    {:ok, view, _html} = live(ctx.conn, ~p"/platform")
    render_click(view, "mark_all_notifications_read")

    assert Notifications.unread_count_for(ctx.user) == 0
    refute render(view) =~ ~s(data-role="notification-count")
  end

  test "an empty bell says so rather than showing nothing", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/platform")

    assert html =~ "Nothing new"
  end
end
