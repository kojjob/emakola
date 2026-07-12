defmodule EmakolaWeb.LandingFooterSeoTest do
  use EmakolaWeb.ConnCase, async: true

  test "landing footer links to region shop pages (internal linking)", %{conn: conn} do
    html = conn |> get("/") |> html_response(200)

    assert html =~ "Shop by region"
    assert html =~ ~s(href="/shops/greater-accra")
    assert html =~ ~s(href="/shops/ashanti")
  end
end
