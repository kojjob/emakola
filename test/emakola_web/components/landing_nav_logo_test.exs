defmodule EmakolaWeb.LandingNavLogoTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  test "the marketing nav renders the mark inline so it can animate" do
    html = render_component(&EmakolaWeb.LandingComponents.landing_nav/1, [])

    assert html =~ "logo-reveal"
    # The coin is tone-invariant: gold face on the nav's brand ink.
    assert html =~ "#d4a843"
    refute html =~ ~s(src="/images/emakola-logo.svg")
  end

  test "the mark is decorative — the wordmark beside it already names the link" do
    html = render_component(&EmakolaWeb.LandingComponents.landing_nav/1, [])

    assert html =~ ~s(aria-hidden="true")
  end
end
