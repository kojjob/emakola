defmodule EmakolaWeb.Company.CareersLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders culture, benefits and a general-application mailto", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/careers")

    assert html =~ "Life at Emakola"
    assert html =~ "No open roles"
    assert html =~ ~s(href="mailto:careers@emakola.com")
    assert html =~ ~s(id="main-nav")
  end
end
