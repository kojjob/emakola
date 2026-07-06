defmodule EmakolaWeb.Storefront.CategoryLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  test "emits apex canonical and BreadcrumbList JSON-LD", %{conn: conn} do
    store = Factory.create_store!(%{name: "Cat Shop", slug: "cat-shop-seo"})
    category = Factory.create_category!(store, %{name: "Spices"})

    {:ok, _view, html} = live(conn, "/s/#{store.slug}/category/#{category.slug}")

    assert html =~
             ~s(<link rel="canonical" href="http://localhost:4000/s/#{store.slug}/category/#{category.slug}")

    assert html =~ ~s("@type":"BreadcrumbList")
    assert html =~ ~s("name":"Spices")
  end
end
