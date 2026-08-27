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

  # One tap, saved. No Save button to find and forget — the audience for this
  # page does not read fluently.
  defp toggle(view, event, channel) do
    view
    |> element(
      ~s([phx-click="toggle_channel"][phx-value-notification="#{event}"][phx-value-channel="#{channel}"])
    )
    |> render_click()
  end

  test "switching a channel off records it immediately", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    toggle(view, "new_message", "sms")

    channels = Preferences.channels_for(ctx.merchant, :new_message)

    refute :sms in channels
    assert :whatsapp in channels
  end

  test "switching one back on records that too", ctx do
    {:ok, _} = Preferences.put_channels(ctx.merchant, :new_message, [:in_app])

    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    toggle(view, "new_message", "sms")

    assert :sms in Preferences.channels_for(ctx.merchant, :new_message)
  end

  test "a switch reflects its state to screen readers", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/admin/settings/notifications")

    # A bare toggle is a div to a screen reader without these.
    assert html =~ ~s(role="switch")
    assert html =~ ~s(aria-checked)
  end

  test "an event that cannot be silenced offers no switch", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/admin/settings/notifications")

    # payout_sent is in @always_on. Rendering a control that silently does
    # nothing is exactly the placebo this project forbids — so it is shown as
    # fixed, with a reason, and no toggle.
    assert html =~ "Always on"
    refute html =~ ~s(phx-value-notification="payout_sent")
  end

  test "a forged event name changes nothing", ctx do
    {:ok, view, _html} = live(ctx.conn, ~p"/admin/settings/notifications")

    # The names arrive from the client; only the configurable list is honoured.
    render_click(view, "toggle_channel", %{"notification" => "payout_sent", "channel" => "sms"})
    render_click(view, "toggle_channel", %{"notification" => "nonsense", "channel" => "sms"})

    assert Preferences.settings(ctx.merchant).overrides == %{}
  end

  test "each event carries an icon, not just a label", ctx do
    {:ok, _view, html} = live(ctx.conn, ~p"/admin/settings/notifications")

    # Merchants here often do not read fluently — the same icon language the
    # notification bell uses.
    assert html =~ "material-symbols-outlined"
    assert html =~ "chat_bubble"
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

    toggle(view, "new_message", "sms")

    assert Preferences.settings(other).overrides == %{}
  end
end
