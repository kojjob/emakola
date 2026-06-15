defmodule EmakolaWeb.Company.PressLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders boilerplate, brand asset download, and press contact", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/press")

    assert html =~ "Press &amp; media" or html =~ "Press"
    assert html =~ "Brand assets"
    assert html =~ ~s(href="/images/emakola-logo.svg")
    assert html =~ ~s(href="mailto:press@emakola.com")
  end
end
