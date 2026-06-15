defmodule EmakolaWeb.Company.TermsLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders terms sections", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/terms")

    assert html =~ "Terms of Service"
    assert html =~ "Acceptance"
    assert html =~ "Merchant obligations"
    assert html =~ "Limitation of liability"
    assert html =~ ~s(href="#merchant-obligations")
  end
end
