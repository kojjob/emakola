defmodule EmakolaWeb.SitemapControllerTest do
  @moduledoc """
  Tests for the per-store sitemap.xml endpoint.

  The sitemap is the primary mechanism for Google to discover all product
  and content pages for each Makola storefront. Without it, products
  that are only reachable via JS-driven pagination or search may never
  be indexed.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup do
    store = create_store!()
    {:ok, store: store}
  end

  describe "GET /sitemap.xml (platform) — programmatic region pages" do
    defp region_store!(region) do
      create_store!(%{
        name: "Shop #{System.unique_integer([:positive])}",
        slug: "shop-#{System.unique_integer([:positive])}",
        region: region,
        active: true
      })
    end

    test "lists indexable region pages and omits thin ones", %{conn: conn} do
      for _ <- 1..3, do: region_store!("Greater Accra")
      region_store!("Ashanti")

      body = conn |> get("/sitemap.xml") |> response(200)

      assert body =~ "/shops/greater-accra"
      refute body =~ "/shops/ashanti"

      # sell-online pages are listed for every region, regardless of shop count
      assert body =~ "/sell-online/greater-accra"
      assert body =~ "/sell-online/ashanti"
    end
  end

  describe "GET /s/:store_slug/sitemap.xml" do
    test "returns valid XML with correct content type", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/sitemap.xml")

      assert response_content_type(conn, :xml) =~ "xml"
      assert conn.status == 200

      body = response(conn, 200)
      assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert body =~ ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">)
      assert body =~ ~s(</urlset>)
    end

    test "includes store home URL", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "/s/#{store.slug}</loc>"
    end

    test "<loc> URLs use the canonical apex host, not the request host", %{
      conn: conn,
      store: store
    } do
      apex = EmakolaWeb.SEO.Canonical.base()

      body =
        %{conn | host: "tenant-subdomain.example.com"}
        |> get("/s/#{store.slug}/sitemap.xml")
        |> response(200)

      assert body =~ "#{apex}/s/#{store.slug}</loc>"
      refute body =~ "tenant-subdomain.example.com"
    end

    test "includes active product URLs", %{conn: conn, store: store} do
      product = create_product!(store, title: "Kente Cloth", status: :active)

      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "/s/#{store.slug}/products/#{product.slug}"
    end

    test "excludes draft and archived products", %{conn: conn, store: store} do
      draft = create_product!(store, title: "Draft Product", status: :draft)
      archived = create_product!(store, title: "Archived Product", status: :archived)

      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      refute body =~ "/products/#{draft.slug}"
      refute body =~ "/products/#{archived.slug}"
    end

    test "includes category URLs", %{conn: conn, store: store} do
      category =
        Emakola.Catalog.Category
        |> Ash.Changeset.for_create(:create, %{
          name: "Textiles",
          store_id: store.id
        })
        |> Ash.create!(authorize?: false)

      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "/s/#{store.slug}/category/#{category.slug}"
    end

    test "includes all indexable static content hubs", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      assert body =~ "/s/#{store.slug}/products</loc>"
      assert body =~ "/s/#{store.slug}/about</loc>"
      assert body =~ "/s/#{store.slug}/contact</loc>"
      assert body =~ "/s/#{store.slug}/faq</loc>"
      assert body =~ "/s/#{store.slug}/policies</loc>"
      assert body =~ "/s/#{store.slug}/blog</loc>"
      assert body =~ "/s/#{store.slug}/recipes</loc>"
    end

    test "returns 404 for non-existent store", %{conn: conn} do
      conn = get(conn, "/s/nonexistent-store/sitemap.xml")
      assert conn.status == 404
    end

    test "does not include private pages (cart, checkout, account)", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      refute body =~ "/cart"
      refute body =~ "/checkout"
      refute body =~ "/account"
      refute body =~ "/wishlist"
      refute body =~ "/track/"
    end

    test "each URL entry has proper sitemap structure", %{conn: conn, store: store} do
      _product = create_product!(store, title: "Test Item", status: :active)

      body = conn |> get("/s/#{store.slug}/sitemap.xml") |> response(200)

      # Each <url> must have a <loc> child
      url_count = body |> String.split("<url>") |> length() |> Kernel.-(1)
      loc_count = body |> String.split("<loc>") |> length() |> Kernel.-(1)

      assert url_count > 0
      assert url_count == loc_count
    end
  end

  # ── robots.txt ──────────────────────────────────────────────────────

  describe "GET /s/:store_slug/robots.txt" do
    test "returns text/plain with sitemap reference", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/robots.txt")

      assert conn.status == 200
      assert response_content_type(conn, :text) =~ "text/plain"

      body = response(conn, 200)
      assert body =~ "Sitemap:"
      assert body =~ "/s/#{store.slug}/sitemap.xml"
    end

    test "disallows private pages", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/robots.txt") |> response(200)

      assert body =~ "Disallow: /s/#{store.slug}/cart"
      assert body =~ "Disallow: /s/#{store.slug}/checkout"
      assert body =~ "Disallow: /s/#{store.slug}/account"
    end

    test "explicitly allows AI crawlers", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/robots.txt") |> response(200)

      assert body =~ "User-Agent: GPTBot"
      assert body =~ "User-Agent: Google-Extended"
      assert body =~ "User-Agent: ClaudeBot"
      assert body =~ "User-Agent: PerplexityBot"
    end

    test "returns 404 for non-existent store", %{conn: conn} do
      conn = get(conn, "/s/nonexistent-store/robots.txt")
      assert conn.status == 404
    end
  end

  # ── llms.txt ────────────────────────────────────────────────────────

  describe "GET /s/:store_slug/llms.txt" do
    test "returns text/plain with store description", %{conn: conn, store: store} do
      conn = get(conn, "/s/#{store.slug}/llms.txt")

      assert conn.status == 200
      assert response_content_type(conn, :text) =~ "text/plain"

      body = response(conn, 200)
      assert body =~ "# #{store.name}"
      assert body =~ "Makola"
    end

    test "lists active products", %{conn: conn, store: store} do
      product = create_product!(store, title: "Kente Cloth", status: :active)

      body = conn |> get("/s/#{store.slug}/llms.txt") |> response(200)

      assert body =~ "Kente Cloth"
      assert body =~ "/products/#{product.slug}"
    end

    test "includes navigation links", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/llms.txt") |> response(200)

      assert body =~ "/s/#{store.slug}/products"
      assert body =~ "/s/#{store.slug}/about"
      assert body =~ "/s/#{store.slug}/sitemap.xml"
    end

    test "includes AI assistant guidance", %{conn: conn, store: store} do
      body = conn |> get("/s/#{store.slug}/llms.txt") |> response(200)

      assert body =~ "For AI assistants"
      assert body =~ "GHS"
      assert body =~ "mobile money"
    end

    test "returns 404 for non-existent store", %{conn: conn} do
      conn = get(conn, "/s/nonexistent-store/llms.txt")
      assert conn.status == 404
    end
  end

  describe "platform sitemap" do
    test "GET /sitemap.xml lists the marketing pages", %{conn: conn} do
      conn = get(conn, "/sitemap.xml")
      body = response(conn, 200)

      assert response_content_type(conn, :xml) =~ "xml"
      assert body =~ ~s(<?xml version="1.0" encoding="UTF-8"?>)
      assert body =~ "<urlset"
      assert body =~ ~r{<loc>https?://[^<]+/</loc>}
      assert body =~ "/pricing</loc>"
      assert body =~ "/stores</loc>"
      assert body =~ "/docs</loc>"
      assert body =~ "</urlset>"
    end
  end

  describe "GET /llms.txt (platform)" do
    test "describes the platform and links authoritative pages", %{conn: conn} do
      conn = get(conn, "/llms.txt")
      body = response(conn, 200)

      assert response_content_type(conn, :text) =~ "text/plain"
      assert body =~ "# Makola"
      assert body =~ "/pricing"
      assert body =~ "/docs"
      assert body =~ "/sitemap.xml"
    end
  end
end
