defmodule EmakolaWeb.Company.LegalLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "links to privacy, terms and cookie pages", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/legal")

    assert html =~ ~s(href="/privacy")
    assert html =~ ~s(href="/terms")
    assert html =~ ~s(href="/cookies")
  end
end
