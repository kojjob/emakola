defmodule EmakolaWeb.StoresLiveTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  alias Emakola.Factory

  describe "GET /stores (public directory)" do
    test "renders publicly without authentication", %{conn: conn} do
      assert {:ok, _view, html} = live(conn, "/stores")
      assert html =~ "Browse Stores"
    end

    test "lists active stores with links to their storefronts", %{conn: conn} do
      Factory.create_store!(%{
        name: "Akosua's Boutique",
        slug: "akosua-boutique",
        description: "Handmade Ankara fashion from Accra",
        city: "Accra",
        region: "Greater Accra"
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
      assert html =~ "No stores yet"
    end
  end
end
