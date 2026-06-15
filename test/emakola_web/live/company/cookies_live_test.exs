defmodule EmakolaWeb.Company.CookiesLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders cookie sections", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/cookies")

    assert html =~ "Cookie Policy"
    assert html =~ "What cookies are"
    assert html =~ "Managing cookies"
    assert html =~ ~s(href="#categories")
  end
end
