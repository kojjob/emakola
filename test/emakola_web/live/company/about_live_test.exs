defmodule EmakolaWeb.Company.AboutLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "renders mission, values and CTAs", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")

    assert html =~ "West Africa"
    assert html =~ "Our mission"
    assert html =~ ~s(id="main-nav")
    assert html =~ ~s(href="/careers")
    assert html =~ ~s(href="/auth/register")
  end

  test "sets SEO title and canonical", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/about")
    assert html =~ "About"
    assert html =~ ~s(rel="canonical")
  end
end
