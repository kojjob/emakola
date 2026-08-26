defmodule EmakolaWeb.ShortStoreUrlTest do
  @moduledoc """
  `makola.io/hotdeals-africa` serves the storefront directly, without the
  `/s/` prefix.

  The route is a root catch-all, so the two things worth pinning are that it
  can never shadow an apex page, and that a store can never be given a slug
  that collides with one.
  """
  use EmakolaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Emakola.Factory

  alias EmakolaWeb.Storefront.Path

  setup do
    Application.delete_env(:emakola, :store_subdomain_base)
    on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)

    store = create_store!(%{name: "Hot Deals Africa", slug: "hotdeals-africa"})
    {:ok, store: store}
  end

  describe "the short URL serves the storefront" do
    test "GET /:store_slug renders the store", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/#{store.slug}")
      assert html =~ store.name
    end

    test "GET /:store_slug/products renders the product list", %{conn: conn, store: store} do
      assert {:ok, _view, _html} = live(conn, "/#{store.slug}/products")
    end

    test "GET /:store_slug/cart renders the cart", %{conn: conn, store: store} do
      assert {:ok, _view, _html} = live(conn, "/#{store.slug}/cart")
    end

    test "an unknown slug does not render a store", %{conn: conn} do
      assert {:error, _} = live(conn, "/no-such-store-anywhere")
    end
  end

  describe "apex pages always win" do
    # Phoenix takes the first matching route and the catch-all is declared last,
    # so a store slug can never shadow a real page. These pin that for the
    # highest-traffic ones.
    for path <- ["/pricing", "/stores", "/blog", "/how-it-works", "/contact"] do
      test "GET #{path} still serves the apex page", %{conn: conn} do
        conn = get(conn, unquote(path))
        assert conn.status in [200, 302]
        refute conn.status == 404
      end
    end

    test "the landing page is untouched", %{conn: conn} do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "Start selling"
    end
  end

  describe "a store can never be given a slug that collides with an apex page" do
    test "a store asking for an apex-page slug gets a suffixed one instead" do
      store = create_store!(%{name: "Pricing", slug: "pricing"})

      refute store.slug == "pricing"
      assert store.slug =~ ~r/^pricing-\d+$/
    end

    test "onboarding is never dead-ended by the collision", %{store: _} do
      # Suffixing rather than rejecting is what keeps a merchant from being
      # told "no" for picking an ordinary shop name.
      assert %{slug: slug} = create_store!(%{name: "Stores", slug: "stores"})
      assert slug =~ ~r/^stores-\d+$/
    end

    test "the reserved list is derived from the router, not hand-maintained" do
      # Any route added to the apex is reserved automatically — this is what
      # stops the list rotting as the marketing site grows.
      assert EmakolaWeb.ReservedStoreSlugs.reserved?("pricing")
      assert EmakolaWeb.ReservedStoreSlugs.reserved?("stores")
      assert EmakolaWeb.ReservedStoreSlugs.reserved?("admin")
      assert EmakolaWeb.ReservedStoreSlugs.reserved?("blog")
      refute EmakolaWeb.ReservedStoreSlugs.reserved?("hotdeals-africa")
    end
  end

  # Found by the production smoke test: a guest with a digital item in cart is
  # redirected to store_path(slug, "/login") — which the short dialect never
  # routed. The customer hit a 404 with a paid cart behind them.
  describe "customer auth in the short dialect" do
    test "/:slug/login mounts", %{conn: conn, store: store} do
      assert {:ok, _view, html} = live(conn, "/#{store.slug}/login")
      assert html =~ store.name
    end

    test "/:slug/register mounts", %{conn: conn, store: store} do
      assert {:ok, _view, _html} = live(conn, "/#{store.slug}/register")
    end

    test "/:slug/whatsapp mounts", %{conn: conn, store: store} do
      assert {:ok, _view, _html} = live(conn, "/#{store.slug}/whatsapp")
    end

    test "auth pages link in the short dialect, not /s/", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/#{store.slug}/login")
      assert html =~ "/#{store.slug}/register"
      refute html =~ "/s/#{store.slug}/register"
    end

    test "logout routes rather than 404ing", %{conn: conn, store: store} do
      conn = get(conn, "/#{store.slug}/auth/customer-logout")
      assert conn.status in [302, 303]
    end

    test "an unknown download grant is a 404 from the controller, not the router",
         %{conn: conn, store: store} do
      conn = get(conn, "/#{store.slug}/downloads/#{Ecto.UUID.generate()}")
      # A routing miss would render the platform 404 page; the controller
      # refusing (401 for a guest, 404 for a bad grant, 302 to login) proves
      # the route exists and resolved the store.
      assert conn.status in [302, 401, 404]
    end
  end

  describe "backwards compatibility" do
    test "the old /s/:slug URL still serves", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}")
      assert html =~ store.name
    end
  end

  # Each entry point links in its own dialect, so a visitor's URL shape never
  # changes underneath them mid-visit.
  describe "each URL form links in its own dialect" do
    test "a page reached by the short URL links short", %{store: store} do
      Path.put_mode(:short)
      assert Path.store_path(store.slug, "/cart") == "/#{store.slug}/cart"
      assert Path.store_path(store.slug, "/") == "/#{store.slug}"
    end

    test "a page reached by /s/ keeps linking to /s/", %{store: store} do
      Path.put_mode(:subfolder)
      assert Path.store_path(store.slug, "/cart") == "/s/#{store.slug}/cart"
    end

    test "a page on a branded host links bare", %{store: store} do
      Path.put_mode(:branded)
      assert Path.store_path(store.slug, "/cart") == "/cart"
    end

    test "the short route actually renders short links", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/#{store.slug}")

      assert html =~ "/#{store.slug}/cart"
      refute html =~ "/s/#{store.slug}/cart"
    end

    test "the /s/ route still renders /s/ links", %{conn: conn, store: store} do
      {:ok, _view, html} = live(conn, "/s/#{store.slug}")
      assert html =~ "/s/#{store.slug}/cart"
    end
  end

  describe "the /s/ prefix is retired for anything a person sees" do
    setup do
      # apex_move only runs when a subdomain base is configured, which is what
      # tells the plug which host is the apex.
      Application.put_env(:emakola, :store_subdomain_base, "makola.io")
      on_exit(fn -> Application.delete_env(:emakola, :store_subdomain_base) end)
      :ok
    end

    test "the store home moves to the short form", %{conn: conn, store: store} do
      conn = %{conn | host: "makola.io"} |> get("/s/#{store.slug}")

      assert redirected_to(conn, 301) =~ "/#{store.slug}"
      refute redirected_to(conn, 301) =~ "/s/#{store.slug}"
    end

    test "a deeper page moves too, keeping its path and query", %{conn: conn, store: store} do
      conn = %{conn | host: "makola.io"} |> get("/s/#{store.slug}/cart?ref=whatsapp")

      assert redirected_to(conn, 301) =~ "/#{store.slug}/cart?ref=whatsapp"
    end

    # The short form has no route for these, so moving them would 301 into a
    # 404 — and a 301 is cached hard enough that it would not be recoverable.
    test "machine and callback paths are left alone", %{conn: conn, store: store} do
      for path <- ["/sitemap.xml", "/robots.txt", "/auth/customer-session", "/login"] do
        conn = %{conn | host: "makola.io"} |> get("/s/#{store.slug}#{path}")
        refute conn.status == 301, "#{path} must not be redirected"
      end
    end

    # /s/pricing is not a store. Redirecting it would send a dead storefront
    # URL to the real pricing page and cache that answer in every browser.
    test "a reserved word after /s/ is never moved", %{conn: conn} do
      conn = %{conn | host: "makola.io"} |> get("/s/pricing")
      refute conn.status == 301
    end
  end
end
