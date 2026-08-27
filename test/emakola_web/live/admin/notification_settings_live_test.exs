defmodule EmakolaWeb.Admin.NotificationSettingsLiveTest do
  @moduledoc """
  Where a merchant turns the noise down.

  Every control here must move something real — a page of switches that
  records nothing is the placebo this project rules out. So each test asserts
  on `Preferences`, not on the markup.
  """
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Notifications.Preferences

  setup %{conn: conn} do
    {merchant, store} = Factory.create_merchant_with_store!(%{name: "Quiet Shop"})

    merchant =
      merchant
      |> Ash.Changeset.for_update(:update_profile, %{phone: "+233241112222"})
      |> Ash.update!(authorize?: false)

    token = EmakolaWeb.AuthTokens.sign_subject(AshAuthentication.user_to_subject(merchant))

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> Plug.Conn.put_session(:user_token, token)

    %{conn: conn, merchant: merchant, store: store}
  end

  test "the page opens", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/admin/settings/notifications")

    assert html =~ "Notifications"
  end

  test "switching a channel off records it", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    view
    |> form("#notification-preferences",
      preferences: %{"new_message" => %{"sms" => "false", "whatsapp" => "true"}}
    )
    |> render_submit()

    channels = Preferences.channels_for(ctx.merchant, :new_message)

    refute :sms in channels
    assert :whatsapp in channels
  end

  test "switching one back on records that too", ctx do
    {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    view
    |> form("#notification-preferences",
      preferences: %{"new_message" => %{"sms" => "true", "whatsapp" => "true"}}
    )
    |> render_submit()

    assert :sms in Preferences.channels_for(ctx.merchant, :new_message)
  end

  test "an event that cannot be silenced offers no switch", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/admin/settings/notifications")

    # payout_sent is in @always_on. Rendering a control that silently does
    # nothing is exactly the placebo this project forbids — so it is shown as
    # fixed, with a reason, and no toggle.
    assert html =~ "Always on"
    refute html =~ ~s(name="preferences[payout_sent])
  end

  test "saving quiet hours records them", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    view
    |> form("#quiet-hours", quiet_hours: %{"start" => "22:00", "end" => "06:00"})
    |> render_submit()

    assert Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 23:30:00Z])
    refute Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 14:00:00Z])
  end

  test "clearing quiet hours turns them off", ctx do
    {:ok, _} = Preferences.put_quiet_hours(ctx.merchant, ~T[22:00:00], ~T[06:00:00])

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    view
    |> form("#quiet-hours", quiet_hours: %{"start" => "", "end" => ""})
    |> render_submit()

    refute Preferences.quiet?(ctx.merchant, :new_message, ~U[2026-08-26 23:30:00Z])
  end

  test "one merchant's settings never reach another", ctx do
    other = Factory.create_merchant!()

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    view
    |> form("#notification-preferences",
      preferences: %{"new_message" => %{"sms" => "false", "whatsapp" => "false"}}
    )
    |> render_submit()

    assert Preferences.settings(other).overrides == %{}
  end
end
