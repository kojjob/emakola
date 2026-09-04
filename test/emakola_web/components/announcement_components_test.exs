defmodule EmakolaWeb.AnnouncementComponentsTest do
  @moduledoc """
  The announcement card says what kind of news it is before a word is read:
  one icon and one tint per severity, and one big button to put it away.
  """
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EmakolaWeb.AnnouncementComponents

  defp render_banner(severity, opts \\ []) do
    render_component(
      &AnnouncementComponents.announcement_banner/1,
      Keyword.merge(
        [
          announcement: %{
            id: "a1",
            title: "Payouts pause on Friday",
            body: "MTN MoMo maintenance, 10pm to 2am.",
            severity: severity
          }
        ],
        opts
      )
    )
  end

  test "info is the brand's emerald with a megaphone, not a blue warning" do
    html = render_banner(:info)

    assert html =~ ~s(id="announcement-a1")
    assert html =~ ~s(data-severity="info")
    assert html =~ "hero-megaphone"
    assert html =~ "from-emerald-500"
    refute html =~ "blue"
  end

  test "warning and critical carry their own icon and tint" do
    warning = render_banner(:warning)
    assert warning =~ "hero-exclamation-triangle"
    assert warning =~ "from-amber-400"

    critical = render_banner(:critical)
    assert critical =~ "hero-bell-alert"
    assert critical =~ "from-red-500"
  end

  test "the title, the body and one Got it button that dismisses" do
    html = render_banner(:info)

    assert html =~ "Payouts pause on Friday"
    assert html =~ "MTN MoMo maintenance, 10pm to 2am."
    assert html =~ ~s(phx-click="dismiss_announcement")
    assert html =~ ~s(phx-value-id="a1")
    assert html =~ "Got it"
  end

  test "a preview looks the same but has nothing to dismiss" do
    html = render_banner(:warning, preview: true)

    assert html =~ "Got it"
    refute html =~ "dismiss_announcement"
    refute html =~ "phx-value-id"
  end
end
