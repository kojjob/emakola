defmodule EmakolaWeb.LandingFooterLinksTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import EmakolaWeb.LandingComponents

  test "Company and Legal footer links point to real routes, not '#'" do
    html = render_component(&landing_footer/1, %{})

    for path <- ~w(/about /careers /press /contact /privacy /terms /cookies) do
      assert html =~ ~s(href="#{path}")
    end
  end
end
