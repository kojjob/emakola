defmodule EmakolaWeb.SitemapSubdomainTest do
  @moduledoc """
  When `:store_subdomain_base` is configured, the per-store sitemap lists each
  store's own subdomain URLs (the SEO-primary host) instead of the apex /s/:slug
  subfolder — matching the rel=canonical flip in EmakolaWeb.SEO.Canonical.

  async: false because it mutates the global :store_subdomain_base app env.
  """
  use EmakolaWeb.ConnCase, async: false

  import Emakola.Factory

  setup do
    previous = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")

    on_exit(fn ->
      if previous,
        do: Application.put_env(:emakola, :store_subdomain_base, previous),
        else: Application.delete_env(:emakola, :store_subdomain_base)
    end)

    store = create_store!()
    origin = "#{URI.parse(EmakolaWeb.Endpoint.url()).scheme}://#{store.slug}.makola.io"
    %{store: store, origin: origin}
  end

  describe "store sitemap <loc> URLs (subdomain base configured)" do
    test "static pages use the store subdomain root, not /s/:slug", %{
      conn: conn,
      store: store,
      origin: origin
    } do
      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "<loc>#{origin}</loc>"
      assert body =~ "<loc>#{origin}/products</loc>"
      assert body =~ "<loc>#{origin}/about</loc>"
      refute body =~ "/s/#{store.slug}"
    end

    test "active product URLs are subdomain-rooted", %{conn: conn, store: store, origin: origin} do
      product = create_product!(store, title: "Kente Cloth", status: :active)

      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "<loc>#{origin}/products/#{product.slug}</loc>"
    end

    test "category URLs are subdomain-rooted", %{conn: conn, store: store, origin: origin} do
      category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{name: "Textiles", store_id: store.id})
        |> Ash.create!(authorize?: false)

      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "<loc>#{origin}/category/#{category.slug}</loc>"
    end
  end

  describe "GET /sitemap.xml routed by host" do
    test "a store subdomain serves that store's sitemap (not the platform one)", %{
      conn: conn,
      store: store,
      origin: origin
    } do
      product = create_product!(store, title: "Kente Cloth", status: :active)

      body =
        %{conn | host: "#{store.slug}.makola.io"}
        |> get("/sitemap.xml")
        |> response(200)

      assert body =~ "<loc>#{origin}/products/#{product.slug}</loc>"
      refute body =~ "/pricing</loc>"
    end

    test "the apex host still serves the platform sitemap", %{conn: conn} do
      body =
        %{conn | host: "makola.io"}
        |> get("/sitemap.xml")
        |> response(200)

      assert body =~ "/pricing</loc>"
    end

    test "an unknown subdomain returns 404", %{conn: conn} do
      conn = %{conn | host: "definitely-not-a-real-store-xyz.makola.io"} |> get("/sitemap.xml")
      assert conn.status == 404
    end
  end

  describe "GET /robots.txt routed by host" do
    test "a store subdomain serves dynamic store robots (root-relative, own sitemap)", %{
      conn: conn,
      store: store,
      origin: origin
    } do
      body =
        %{conn | host: "#{store.slug}.makola.io"}
        |> get("/robots.txt")
        |> response(200)

      assert body =~ "Sitemap: #{origin}/sitemap.xml"
      assert body =~ "Disallow: /cart"
      # store robots, NOT the generic platform robots, and root-relative on the subdomain
      refute body =~ "Disallow: /dashboard"
      refute body =~ "Disallow: /s/#{store.slug}"
    end

    test "the apex serves platform robots (dynamic, not the static file)", %{conn: conn} do
      body =
        %{conn | host: "makola.io"}
        |> get("/robots.txt")
        |> response(200)

      assert body =~ "Disallow: /dashboard"
      assert body =~ "Sitemap:"
    end

    test "the apex /s/:slug route still serves store robots in subfolder form", %{
      conn: conn,
      store: store
    } do
      body = conn |> get("/s/#{store.slug}/robots.txt") |> response(200)

      assert body =~ "Disallow: /s/#{store.slug}/cart"
    end
  end
end
