defmodule EmakolaWeb.LandingNavLogoTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "the marketing nav renders the mark inline so it can animate" do
    html = render_component(&EmakolaWeb.LandingComponents.landing_nav/1, [])

    assert html =~ "logo-reveal"
    # Reversed tone: the nav sits on brand ink.
    assert html =~ "#f1f5f9"
    refute html =~ ~s(src="/images/emakola-logo.svg")
  end

  test "the mark is decorative — the wordmark beside it already names the link" do
    html = render_component(&EmakolaWeb.LandingComponents.landing_nav/1, [])

    assert html =~ ~s(aria-hidden="true")
  end
end
