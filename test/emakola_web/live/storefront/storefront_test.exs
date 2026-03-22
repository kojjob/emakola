defmodule EmakolaWeb.Storefront.StorefrontTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Ghana Shop", slug: "ghana-shop", currency: "GHS"})
    %{store: store}
  end

  # -- Store Landing Page --

  describe "StoreLive" do
    test "renders store landing page with store name", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ store.name
    end

    test "shows featured active products", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Active Widget"})
      _variant = Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Active Widget"
    end

    test "does not show draft products", %{conn: conn, store: store} do
      _draft = Factory.create_product!(store, %{title: "Draft Widget"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      refute html =~ "Draft Widget"
    end

    test "shows root categories", %{conn: conn, store: store} do
      _cat = Factory.create_category!(store, %{name: "Electronics"})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}")

      assert html =~ "Electronics"
    end

    test "redirects for non-existent store slug", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store")
    end
  end

  # -- Product List Page --

  describe "ProductListLive" do
    test "shows active products only", %{conn: conn, store: store} do
      active_product = Factory.create_product!(store, %{title: "Active Gadget"})
      Factory.create_variant!(active_product, store, %{price: 3000, stock_quantity: 5})
      activate_product!(active_product)

      draft_product = Factory.create_product!(store, %{title: "Draft Gadget"})
      Factory.create_variant!(draft_product, store, %{price: 2000, stock_quantity: 3})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products")

      assert html =~ "Active Gadget"
      refute html =~ "Draft Gadget"
    end

    test "displays product prices in store currency", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Priced Item"})
      Factory.create_variant!(product, store, %{price: 15000, stock_quantity: 10})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products")

      assert html =~ "GH\u20B5"
    end

    test "search returns matching products", %{conn: conn, store: store} do
      product_a = Factory.create_product!(store, %{title: "Blue Shirt"})
      Factory.create_variant!(product_a, store, %{price: 5000, stock_quantity: 10})
      activate_product!(product_a)

      product_b = Factory.create_product!(store, %{title: "Red Hat"})
      Factory.create_variant!(product_b, store, %{price: 3000, stock_quantity: 5})
      activate_product!(product_b)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products")

      html = view |> element("form") |> render_change(%{query: "Blue"})

      assert html =~ "Blue Shirt"
      refute html =~ "Red Hat"
    end

    test "category filter shows products in category", %{conn: conn, store: store} do
      cat = Factory.create_category!(store, %{name: "Clothing"})

      product_in_cat = Factory.create_product!(store, %{title: "T-Shirt", category_id: cat.id})
      Factory.create_variant!(product_in_cat, store, %{price: 5000, stock_quantity: 10})
      activate_product!(product_in_cat)

      product_outside = Factory.create_product!(store, %{title: "Phone Case"})
      Factory.create_variant!(product_outside, store, %{price: 3000, stock_quantity: 5})
      activate_product!(product_outside)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products")

      html = render_click(view, "filter_category", %{category_id: cat.id})

      assert html =~ "T-Shirt"
      refute html =~ "Phone Case"
    end
  end

  # -- Product Detail Page --

  describe "ProductDetailLive" do
    test "shows product details with variant price", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Fancy Bag", description: "A fancy bag"})
      Factory.create_variant!(product, store, %{price: 25000, stock_quantity: 10, sku: "BAG-001"})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Fancy Bag"
      assert html =~ "A fancy bag"
      assert html =~ "GH\u20B5 250.00"
      assert html =~ "In Stock"
      assert html =~ "BAG-001"
    end

    test "shows out of stock status", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Sold Out Item"})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 0})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Out of Stock"
    end

    test "shows low stock warning", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Low Stock Item"})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 3})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      assert html =~ "Low Stock"
      assert html =~ "3 left"
    end

    test "add to cart updates cart count", %{conn: conn, store: store} do
      product = Factory.create_product!(store, %{title: "Cart Item"})
      Factory.create_variant!(product, store, %{price: 5000, stock_quantity: 10})
      activate_product!(product)

      {:ok, view, _html} = live(conn, "/s/#{store.slug}/products/#{product.slug}")

      html = render_click(view, "add_to_cart")

      assert html =~ "Added to cart"
    end

    test "redirects for non-existent product", %{conn: conn, store: store} do
      expected_path = "/s/#{store.slug}/products"

      assert {:error, {:redirect, %{to: ^expected_path}}} =
               live(conn, "/s/#{store.slug}/products/non-existent-product")
    end
  end

  # -- Cart Page --

  describe "CartLive" do
    test "shows empty cart message", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}/cart")

      assert html =~ "empty" or html =~ "Shopping Bag"
    end

    test "redirects for non-existent store", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/s/no-such-store/cart")
    end
  end

  # -- Category Page --

  describe "CategoryLive" do
    test "shows category name and products", %{conn: conn, store: store} do
      cat = Factory.create_category!(store, %{name: "Shoes", description: "All kinds of shoes"})

      product = Factory.create_product!(store, %{title: "Running Shoe", category_id: cat.id})
      Factory.create_variant!(product, store, %{price: 12000, stock_quantity: 8})
      activate_product!(product)

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/category/#{cat.slug}")

      assert html =~ "Shoes"
      assert html =~ "All kinds of shoes"
      assert html =~ "Running Shoe"
    end

    test "does not show draft products in category", %{conn: conn, store: store} do
      cat = Factory.create_category!(store, %{name: "Hidden Category"})

      draft = Factory.create_product!(store, %{title: "Draft Shoe", category_id: cat.id})
      Factory.create_variant!(draft, store, %{price: 5000, stock_quantity: 5})

      {:ok, _view, html} = live(conn, "/s/#{store.slug}/category/#{cat.slug}")

      refute html =~ "Draft Shoe"
    end
  end

  # -- Helpers --

  defp activate_product!(product) do
    product
    |> Ash.Changeset.for_update(:activate, %{})
    |> Ash.update!()
  end
end
