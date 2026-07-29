defmodule EmakolaWeb.InstagramFeedControllerTest do
  @moduledoc """
  Pins the contract for the per-store Instagram Shopping product feed:

    * Returns 200 + application/xml for an existing store
    * Returns 404 for an unknown store slug
    * Includes RSS 2.0 envelope + g: namespace declaration
    * Emits one <item> per active product (archived products excluded)
    * Each item has the required Meta/Google merchant fields:
      g:id, g:title, g:link, g:image_link, g:price, g:availability,
      g:brand, g:condition
  """
  use EmakolaWeb.ConnCase, async: false

  alias Emakola.Factory

  setup do
    store = Factory.create_store!(%{name: "Feed Shop", slug: "feed-shop"})
    {:ok, store: store}
  end

  describe "GET /s/:slug/feed/instagram.xml" do
    test "returns 404 for unknown store", %{conn: conn} do
      conn = get(conn, "/s/no-such-store/feed/instagram.xml")
      assert conn.status == 404
    end

    test "returns 200 + application/xml for known store", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/feed/instagram.xml")
      assert conn.status == 200
      [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "application/xml"
    end

    test "renders RSS 2.0 + g: namespace envelope", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/feed/instagram.xml")
      body = response(conn, 200)

      assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert body =~ ~s(<rss version="2.0" xmlns:g="http://base.google.com/ns/1.0">)
      assert body =~ "<channel>"
      assert body =~ "Feed Shop"
    end

    test "emits one <item> per active product", %{conn: conn, store: store} do
      product1 = create_active_product!(store, %{title: "Active 1"}, %{stock_quantity: 10})
      product2 = create_active_product!(store, %{title: "Active 2"}, %{stock_quantity: 0})

      conn = get(conn, "/s/#{store.slug}/feed/instagram.xml")
      body = response(conn, 200)

      assert body =~ "<g:title>Active 1</g:title>"
      assert body =~ "<g:title>Active 2</g:title>"
      assert body |> String.split("<item>") |> length() == 3
      # Sanity: both ids included
      assert body =~ product1.id
      assert body =~ product2.id
    end

    test "each item has required Meta/Google merchant fields", %{conn: conn, store: store} do
      product =
        create_active_product!(
          store,
          %{title: "Kente Tee", description: "Cotton"},
          %{price: 12_500, stock_quantity: 5}
        )

      conn = get(conn, "/s/#{store.slug}/feed/instagram.xml")
      body = response(conn, 200)

      assert body =~ "<g:id>#{product.id}</g:id>"
      assert body =~ "<g:title>Kente Tee</g:title>"
      assert body =~ "<g:description>Cotton</g:description>"
      assert body =~ "<g:link>"
      assert body =~ "/s/#{store.slug}/products/"
      assert body =~ "<g:availability>in stock</g:availability>"
      assert body =~ "<g:price>125.00 GHS</g:price>"
      assert body =~ "<g:brand>Feed Shop</g:brand>"
      assert body =~ "<g:condition>new</g:condition>"
    end

    test "out of stock variants render availability=\"out of stock\"", %{
      conn: conn,
      store: store
    } do
      _product =
        create_active_product!(store, %{title: "Sold Out"}, %{price: 1_000, stock_quantity: 0})

      conn = get(conn, "/s/#{store.slug}/feed/instagram.xml")
      body = response(conn, 200)

      assert body =~ "<g:availability>out of stock</g:availability>"
    end

    test "untracked zero-stock variants remain in stock", %{conn: conn, store: store} do
      _product =
        create_active_product!(
          store,
          %{title: "Made to Order"},
          %{price: 1_000, stock_quantity: 0, track_inventory: false}
        )

      body = conn |> get("/s/#{store.slug}/feed/products.xml") |> response(200)

      assert body =~ "<g:title>Made to Order</g:title>"
      assert body =~ "<g:availability>in stock</g:availability>"
    end

    test "uses canonical product URLs regardless of request host", %{conn: conn, store: store} do
      product =
        create_active_product!(store, %{title: "Canonical Product"}, %{stock_quantity: 3})

      canonical = EmakolaWeb.SEO.Canonical.product_url(store, product)

      body =
        %{conn | host: "untrusted.example"}
        |> get("/s/#{store.slug}/feed/products.xml")
        |> response(200)

      assert body =~ "<g:link>#{canonical}</g:link>"
      refute body =~ "untrusted.example"
    end

    test "draft (non-active) products are excluded", %{conn: conn, store: store} do
      _draft = Factory.create_product!(store, %{title: "Draft Only"})

      conn = get(conn, "/s/#{store.slug}/feed/instagram.xml")
      body = response(conn, 200)

      refute body =~ "Draft Only"
    end
  end

  # Creates a product with a variant and activates it so it shows in the feed.
  defp create_active_product!(store, product_attrs, variant_attrs) do
    product = Factory.create_product!(store, product_attrs)
    variant_defaults = %{price: 5_000, stock_quantity: 10}
    _v = Factory.create_variant!(product, store, Map.merge(variant_defaults, variant_attrs))
    _image = Factory.create_image!(product, store)

    {:ok, activated} =
      product
      |> Ash.Changeset.for_update(:activate, %{})
      |> Ash.update(authorize?: false)

    activated
  end
end
