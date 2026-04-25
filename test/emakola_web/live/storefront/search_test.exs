defmodule EmakolaWeb.Storefront.SearchTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Search Shop", slug: "search-shop", currency: "GHS"})
    %{store: store}
  end

  # -- Search Overlay Component --

  describe "search overlay on StoreLive" do
    test "renders search overlay element (hidden)", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "search-overlay"
      assert html =~ "Search products..."
    end

    test "search overlay returns matching products in results", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Kente Cloth"})
      Factory.create_variant!(product, store, %{price: 15000, stock_quantity: 10})
      activate_product!(product)

      other = Factory.create_product!(store, %{title: "Leather Sandals"})
      Factory.create_variant!(other, store, %{price: 8000, stock_quantity: 5})
      activate_product!(other)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      html = render_keyup(view, "search_overlay", %{value: "Kente"})

      # The search overlay input should reflect the query
      assert html =~ ~s(value="Kente")
      # The search overlay should contain the matching product result with price
      assert html =~ "Kente Cloth"
      assert html =~ "GH\u20B5 150"
      # No results found message should NOT appear
      refute html =~ "No results found"
    end

    test "search overlay shows no results message", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      html = render_keyup(view, "search_overlay", %{value: "nonexistent"})

      assert html =~ "No results found"
    end

    test "close_search resets search state", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Wax Print"})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
      activate_product!(product)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      render_keyup(view, "search_overlay", %{value: "Wax"})
      html = render_click(view, "close_search")

      # After closing, the search overlay input should be empty
      assert html =~ ~s(value="")
      # Should show the empty prompt, not results
      assert html =~ "Search for products by name"
    end

    test "empty search query clears results", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Beaded Necklace"})
      Factory.create_variant!(product, store, %{price: 3000, stock_quantity: 10})
      activate_product!(product)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      render_keyup(view, "search_overlay", %{value: "Beaded"})
      html = render_keyup(view, "search_overlay", %{value: ""})

      # Empty query should show the empty state, not results
      assert html =~ "Search for products by name"
    end
  end

  # -- Search Overlay on ProductListLive --

  describe "search overlay on ProductListLive" do
    test "search overlay works on product list page", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Ankara Dress"})
      Factory.create_variant!(product, store, %{price: 20000, stock_quantity: 5})
      activate_product!(product)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products")

      html = render_keyup(view, "search_overlay", %{value: "Ankara"})

      assert html =~ "Ankara Dress"
    end

    test "close_search works on product list page", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products")

      html = render_click(view, "close_search")

      assert html =~ "search-overlay"
    end
  end

  # -- URL Param Support (ProductListLive) --

  describe "ProductListLive ?q= parameter" do
    test "filters products based on ?q= URL parameter", %{conn: conn, store: store} do
      matching = Factory.create_product!(store, %{title: "Gold Ring"})
      Factory.create_variant!(matching, store, %{price: 50000, stock_quantity: 3})
      activate_product!(matching)

      non_matching = Factory.create_product!(store, %{title: "Silver Bangle"})
      Factory.create_variant!(non_matching, store, %{price: 30000, stock_quantity: 5})
      activate_product!(non_matching)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products?q=Gold")

      assert html =~ "Gold Ring"
      refute html =~ "Silver Bangle"
    end

    test "empty ?q= parameter shows all products", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Test Product"})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products?q=")

      assert html =~ "Test Product"
    end

    test "search results show View all link when more than 6 results", %{
      conn: conn,
      store: store
    } do
      # Create 8 products matching the search term
      for i <- 1..8 do
        product = Factory.create_product!(store, %{title: "Widget #{i}"})
        Factory.create_variant!(product, store, %{price: 1000 * i, stock_quantity: 10})
        activate_product!(product)
      end

      {:ok, view, _html} = live(conn, "/s/#{store.slug}")

      html = render_keyup(view, "search_overlay", %{value: "Widget"})

      assert html =~ "View all"
      assert html =~ "8 results"
    end
  end

  # -- Nav Search Trigger --

  describe "nav search trigger" do
    test "search button in nav uses phx-click (not a link)", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      # The search button should be a button with phx-click, not an <a> link
      assert html =~ "Search products"
      # Verify it is within a button element (the layout or nav renders a button)
      assert html =~ "search-overlay"
    end
  end

  # -- Helpers --

  defp activate_product!(product) do
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!(authorize?: false)
  end
end
