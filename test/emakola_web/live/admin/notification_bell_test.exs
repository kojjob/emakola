defmodule EmakolaWeb.Admin.NotificationBellTest do
  @moduledoc """
  The merchant's bell, end to end.

  It rendered in the merchant layout from the day it was added and was always
  empty: `Notification` was foreign-keyed to `users` (platform staff) and
  `AssignDefaults` passed `nil` down the merchant path, so
  `load_notifications` short-circuited before it queried anything.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Notifications

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!(%{name: "Bell Shop"})
    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  test "a merchant sees a notification addressed to them", ctx do
    {:ok, _} =
      Notifications.notify(ctx.merchant, :order_placed, %{
        title: "New order from Ama",
        body: "2 items, GH₵20"
      })

    {:ok, _view, html} = live(ctx.conn, ~p"/dashboard")

    assert html =~ "New order from Ama"
  end

  test "another merchant's notification stays out of this bell", ctx do
    other = Factory.create_merchant!()
    {:ok, _} = Notifications.notify(other, :order_placed, %{title: "Not for you"})

    {:ok, _view, html} = live(ctx.conn, ~p"/dashboard")

    refute html =~ "Not for you"
  end

  test "a notification arriving mid-session appears without a refresh", ctx do
    {:ok, view, html} = live(ctx.conn, ~p"/dashboard")
    refute html =~ "Ama sent a message"

    {:ok, _} =
      Notifications.notify(ctx.merchant, :new_message, %{title: "Ama sent a message"})

    assert render(view) =~ "Ama sent a message"
  end

  test "marking all read clears the badge", ctx do
    for i <- 1..3 do
      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Order #{i}"})
    end

    {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")
    assert Notifications.unread_count_for(ctx.merchant) == 3

    render_click(view, "mark_all_notifications_read")

    assert Notifications.unread_count_for(ctx.merchant) == 0
  end

  test "marking all read clears every unread row, not just the loaded page", ctx do
    # The bell loads 20. The old handler looped over what it had loaded, so a
    # 21st notification stayed unread while the badge read zero.
    for i <- 1..25 do
      {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Order #{i}"})
    end

    {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")
    render_click(view, "mark_all_notifications_read")

    assert Notifications.unread_count_for(ctx.merchant) == 0
  end

  test "one merchant clearing their bell leaves another's alone", ctx do
    other = Factory.create_merchant!()
    {:ok, _} = Notifications.notify(ctx.merchant, :order_placed, %{title: "Mine"})
    {:ok, _} = Notifications.notify(other, :order_placed, %{title: "Theirs"})

    {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")
    render_click(view, "mark_all_notifications_read")

    assert Notifications.unread_count_for(other) == 1
  end

  describe "clicking a notification" do
    test "goes to its action_url and marks it read", ctx do
      {:ok, notification} =
        Notifications.notify(ctx.merchant, :order_placed, %{
          title: "New order from Ama",
          action_url: "/admin/orders"
        })

      {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")

      view
      |> element("#notification-#{notification.id}")
      |> render_click()

      assert_redirect(view, "/admin/orders")

      reread = Ash.get!(Emakola.Notifications.Notification, notification.id, authorize?: false)
      refute is_nil(reread.read_at)
    end

    test "falls back to the messages page when it carries no link", ctx do
      {:ok, notification} =
        Notifications.notify(ctx.merchant, :new_message, %{title: "Ama wrote to you"})

      {:ok, view, _html} = live(ctx.conn, ~p"/dashboard")

      view
      |> element("#notification-#{notification.id}")
      |> render_click()

      assert_redirect(view, "/admin/messages")
    end

    test "the dropdown links to the full messages page", ctx do
      {:ok, _} = Notifications.notify(ctx.merchant, :new_message, %{title: "Ama wrote"})

      {:ok, _view, html} = live(ctx.conn, ~p"/dashboard")

      assert html =~ ~s(href="/admin/messages")
    end
  end
end
