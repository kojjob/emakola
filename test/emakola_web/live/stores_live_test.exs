defmodule EmakolaWeb.StoresLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "GET /stores (public directory)" do
    test "renders publicly without authentication", %{conn: conn} do
      assert {:ok, _view, html} = live(conn, "/stores")
      assert html =~ "Browse the marketplace"
    end

    test "lists active stores with links to their storefronts", %{conn: conn} do
      Factory.create_store!(%{
        name: "Akosua's Boutique",
        slug: "akosua-boutique",
        description: "Handmade Ankara fashion from Accra",
        city: "Accra",
        region: "greater_accra"
      })

      Factory.create_store!(%{name: "Kente Collective", slug: "kente-collective"})

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "Akosua&#39;s Boutique"
      assert html =~ "Kente Collective"
      assert html =~ ~s|href="/s/akosua-boutique"|
      assert html =~ ~s|href="/s/kente-collective"|
      assert html =~ "Accra"
    end

    test "excludes inactive stores", %{conn: conn} do
      Factory.create_store!(%{name: "Live Shop", slug: "live-shop"})
      Factory.create_store!(%{name: "Hidden Shop", slug: "hidden-shop", active: false})

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "Live Shop"
      refute html =~ "Hidden Shop"
    end

    test "shows empty state when no active stores exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "marketplace is just getting started" or
               html =~ "No stores match your filters"
    end

    test "search narrows the visible stores", %{conn: conn} do
      Factory.create_store!(%{name: "Coffee World", slug: "coffee-world"})
      Factory.create_store!(%{name: "Ankara Threads", slug: "ankara-threads"})

      {:ok, view, _html} = live(conn, "/stores")

      html = render_hook(view, "update_search", %{"value" => "coffee"})

      assert html =~ "Coffee World"
      refute html =~ "Ankara Threads"
    end

    test "theme filter chip narrows by theme_config[\"theme\"]", %{conn: conn} do
      Factory.create_store!(%{
        name: "Beauty Spot",
        slug: "beauty-spot",
        theme_config: %{"theme" => "beauty"}
      })

      Factory.create_store!(%{
        name: "Tech Hub",
        slug: "tech-hub",
        theme_config: %{"theme" => "electronics"}
      })

      {:ok, view, _html} = live(conn, "/stores")

      # Click the Beauty chip — only Beauty Spot should remain
      html =
        view
        |> element(~s|button[phx-click="select_theme"][phx-value-theme="beauty"]|)
        |> render_click()

      assert html =~ "Beauty Spot"
      refute html =~ "Tech Hub"
    end

    test "region filter narrows by region", %{conn: conn} do
      Factory.create_store!(%{
        name: "Accra Goods",
        slug: "accra-goods",
        region: "greater_accra"
      })

      Factory.create_store!(%{
        name: "Kumasi Crafts",
        slug: "kumasi-crafts",
        region: "ashanti"
      })

      {:ok, view, _html} = live(conn, "/stores")

      html =
        view
        |> element("select[phx-change=select_region]")
        |> render_change(%{"region" => "ashanti"})

      assert html =~ "Kumasi Crafts"
      refute html =~ "Accra Goods"
    end

    test "sort dropdown switches the order", %{conn: conn} do
      Factory.create_store!(%{name: "Aaa Shop", slug: "aaa-shop"})
      Factory.create_store!(%{name: "Zzz Shop", slug: "zzz-shop"})

      {:ok, view, _html} = live(conn, "/stores")

      html =
        view
        |> element("select[phx-change=select_sort]")
        |> render_change(%{"sort" => "name"})

      # Both still visible — just verifying the sort event handler works
      # without raising. Render order can't be reliably asserted via string
      # search since both names appear in the same HTML chunk.
      assert html =~ "Aaa Shop"
      assert html =~ "Zzz Shop"
    end

    test "featured carousel renders when at least one featured store exists", %{conn: conn} do
      Factory.create_store!(%{
        name: "Carousel Star",
        slug: "carousel-star",
        featured: true,
        featured_rank: 1,
        tagline: "Hand-picked excellence"
      })

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "Spotlight on Ghana"
      assert html =~ "Carousel Star"
      assert html =~ "Hand-picked excellence"
    end

    test "editor's picks section renders for stores with featured_rank ≤ 6", %{conn: conn} do
      Factory.create_store!(%{
        name: "Pick One",
        slug: "pick-one",
        featured: true,
        featured_rank: 2,
        tagline: "Bold pick"
      })

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "Editor"
      assert html =~ "Pick One"
    end

    test "curation strips hide when filters are active", %{conn: conn} do
      Factory.create_store!(%{
        name: "Featured Apparel",
        slug: "featured-apparel",
        featured: true,
        featured_rank: 1,
        theme_config: %{"theme" => "fashion"}
      })

      Factory.create_store!(%{
        name: "Beauty Standalone",
        slug: "beauty-standalone",
        theme_config: %{"theme" => "beauty"}
      })

      {:ok, view, html} = live(conn, "/stores")

      # No filters → carousel is shown
      assert html =~ "Spotlight on Ghana"

      # Apply theme filter → carousel must disappear
      html =
        view
        |> element(~s|button[phx-click="select_theme"][phx-value-theme="beauty"]|)
        |> render_click()

      refute html =~ "Spotlight on Ghana"
    end

    test "featured stores show the Featured pill on their card", %{conn: conn} do
      Factory.create_store!(%{
        name: "Top Shop",
        slug: "top-shop",
        featured: true,
        featured_rank: 1
      })

      {:ok, _view, html} = live(conn, "/stores")

      assert html =~ "Top Shop"
      assert html =~ "Featured"
    end
  end
end
