defmodule EmakolaWeb.SidebarMobileDrawerTest do
  @moduledoc """
  The merchant drawer has to actually open on a phone.

  Production served a blurred backdrop with no menu behind it. The aside
  carried Tailwind's `-translate-x-full`, which v4 compiles to the standalone
  `translate` property rather than `transform`, so app.css fought it with a
  `transform` reset *and* a `translate` reset inside one block. Lightning CSS
  — the minifier behind `tailwind --minify` — is entitled to fold those two
  properties together, and it did: the shipped rule read
  `transform:translate(0)translate(0)!important` with the `translate` reset
  gone, leaving the utility's `translate:-100%` in force. Dev never minifies,
  so the drawer worked on every machine except the ones merchants use.

  The drawer's position is now owned by app.css alone, in one property, so
  there is no pair left to merge.
  """

  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias EmakolaWeb.SidebarComponents

  @app_css "assets/css/app.css"

  # Every declaration block in app.css whose selector mentions .sidebar,
  # as {selector, body} pairs.
  defp sidebar_rules do
    @app_css
    |> File.read!()
    |> then(&Regex.scan(~r/([^{}]*\.sidebar\b[^{}]*)\{([^{}]*)\}/, &1))
    |> Enum.map(fn [_match, selector, body] -> {String.trim(selector), body} end)
  end

  defp sidebar_aside do
    html =
      render_component(&SidebarComponents.admin_sidebar/1, %{
        active_nav: :dashboard,
        current_user: nil,
        current_merchant: nil,
        current_store: nil,
        pending_order_count: 0,
        unread_message_count: 0
      })

    case Regex.run(~r{<aside[^>]*id="sidebar"[^>]*>}s, html) do
      [aside] -> aside
      nil -> flunk(~s{no <aside id="sidebar"> in the admin sidebar})
    end
  end

  test "the aside leaves its off-canvas position to app.css" do
    aside = sidebar_aside()

    refute aside =~ "translate-x-full",
           "the aside must not position itself with a Tailwind translate utility"

    refute aside =~ "lg:translate-x-0",
           "the aside must not position itself with a Tailwind translate utility"
  end

  test "no .sidebar rule sets the standalone translate property" do
    offenders =
      for {selector, body} <- sidebar_rules(),
          body =~ ~r/(^|;)\s*translate\s*:/,
          do: selector

    assert offenders == [],
           "these rules pair `translate` with `transform` and the minifier will " <>
             "merge one of them away: #{Enum.join(offenders, ", ")}"
  end

  test "app.css holds the drawer off-canvas until the shell is mobile-open" do
    css = File.read!(@app_css)

    assert css =~ ~r/\.admin-shell \.sidebar\s*\{\s*transform:\s*translateX\(-100%\)/,
           "the drawer must start off-canvas below the lg breakpoint"

    assert css =~ ~r/\.admin-shell\.mobile-open \.sidebar\s*\{\s*transform:\s*translateX\(0\)/,
           "opening the shell must slide the drawer back on-screen"
  end
end
