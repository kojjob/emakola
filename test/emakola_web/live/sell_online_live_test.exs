defmodule EmakolaWeb.SellOnlineLiveTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the sell-online page for a region with apex canonical, indexable", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/sell-online/greater-accra")

    assert html =~ "Start your online shop in Greater Accra"

    assert html =~
             ~s(<link rel="canonical" href="http://localhost:4000/sell-online/greater-accra")

    assert html =~ ~s(<meta name="robots" content="index, follow")
    assert html =~ ~s("@type":"FAQPage")
  end

  test "redirects an unknown region to /pricing", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/pricing"}}} = live(conn, "/sell-online/atlantis")
  end
end
