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

  test "renders category products through a resettable stream", %{conn: conn} do
    store = Factory.create_store!(%{name: "Stream Shop", slug: "category-stream-shop"})
    category = Factory.create_category!(store, %{name: "Streamed Goods"})

    product =
      Factory.create_product!(store, %{title: "Streamed Product", category_id: category.id})

    Factory.create_variant!(product, store, %{price: 1200, stock_quantity: 5})

    product =
      product
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update!(authorize?: false)

    {:ok, view, _html} = live(conn, "/s/#{store.slug}/category/#{category.slug}")

    assert has_element?(view, "#category-products[phx-update='stream'][data-count='1']")
    assert has_element?(view, "#products-#{product.id}")

    render_change(element(view, "#sort-select"), %{"sort" => "name_asc"})

    assert has_element?(view, "#products-#{product.id}")
    assert has_element?(view, "#sort-select option[value='name_asc'][selected]")
  end

  test "renders the streamed category empty state", %{conn: conn} do
    store = Factory.create_store!(%{name: "Empty Shop", slug: "empty-category-shop"})
    category = Factory.create_category!(store, %{name: "Nothing Here"})

    {:ok, view, _html} = live(conn, "/s/#{store.slug}/category/#{category.slug}")

    assert has_element?(view, "#category-products[data-count='0']")
    assert has_element?(view, "#category-products-empty")
  end
end
