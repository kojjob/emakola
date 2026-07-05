defmodule EmakolaWeb.Company.PrivacyLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders privacy sections and last-updated", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/privacy")

    assert html =~ "Privacy Policy"
    assert html =~ "Last updated"
    assert html =~ "Information we collect"
    assert html =~ "Your rights"
    assert html =~ ~s(href="#data-we-collect")
  end
end
