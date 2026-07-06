defmodule EmakolaWeb.LandingFooterSeoTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "landing footer links to region shop pages (internal linking)", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/")

    assert html =~ "Shop by region"
    assert html =~ ~s(href="/shops/greater-accra")
    assert html =~ ~s(href="/shops/ashanti")
  end
end
