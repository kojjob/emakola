defmodule EmakolaWeb.CustomDomainSeoTest do
  @moduledoc """
  Once a store has its own domain, every older address must *move* traffic
  there, not merely point at it.

  Canonical alone is a hint Google may take slowly or ignore; a 301 is the
  definitive signal for a domain move, and it is what carries ranking across.
  """
  use EmakolaWeb.ConnCase, async: false

  import Emakola.Factory

  alias Emakola.Analytics.SearchConsoleCoverage
  alias Emakola.Stores
  alias EmakolaWeb.Plugs.ResolveStoreByHost

  setup do
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    Emakola.Cache.StoreCache.invalidate_all()

    on_exit(fn ->
      Application.delete_env(:emakola, :store_subdomain_base)
      Emakola.Cache.StoreCache.invalidate_all()
    end)

    {:ok, store: create_store!(%{name: "Hot Deals", slug: "hotdeals-africa"})}
  end

  defp with_custom_domain!(store, host) do
    {:ok, d} = Stores.claim_custom_domain(%{store_id: store.id, host: host}, authorize?: false)
    {:ok, d} = Stores.request_domain_verification(d, authorize?: false)
    {:ok, d} = Stores.mark_domain_active(d, authorize?: false)
    {:ok, d} = Stores.make_domain_primary(d, authorize?: false)
    d
  end

  defp call(conn, host, path, query \\ "") do
    %{conn | host: host, request_path: path, query_string: query}
    |> Map.put(:path_info, String.split(path, "/", trim: true))
    |> ResolveStoreByHost.call(ResolveStoreByHost.init([]))
  end

  describe "the store's own subdomain moves to the custom domain" do
    test "301s to the custom domain, preserving path and query", %{conn: conn, store: store} do
      _ = with_custom_domain!(store, "hotdeals.africa")

      conn = call(conn, "#{store.slug}.makola.io", "/products", "page=2")

      assert conn.halted
      assert conn.status == 301
      assert ["http://hotdeals.africa/products?page=2"] = get_resp_header(conn, "location")
    end

    test "keeps serving normally when there is no custom domain", %{conn: conn, store: store} do
      conn = call(conn, "#{store.slug}.makola.io", "/products")
      refute conn.halted
    end

    test "stops redirecting once the custom domain is retired", %{conn: conn, store: store} do
      domain = with_custom_domain!(store, "hotdeals.africa")
      assert call(conn, "#{store.slug}.makola.io", "/").halted

      {:ok, _} = Stores.expire_store_domain(domain, %{reason: "revoked"}, authorize?: false)

      refute call(conn, "#{store.slug}.makola.io", "/").halted
    end
  end

  describe "the apex subfolder moves to the custom domain" do
    test "/s/:slug 301s to the custom domain", %{conn: conn, store: store} do
      _ = with_custom_domain!(store, "hotdeals.africa")

      conn = call(conn, "makola.io", "/s/#{store.slug}/cart")

      assert conn.halted
      assert conn.status == 301
      assert ["http://hotdeals.africa/cart"] = get_resp_header(conn, "location")
    end

    test "/s/:slug is untouched with no custom domain", %{conn: conn, store: store} do
      refute call(conn, "makola.io", "/s/#{store.slug}/cart").halted
    end

    test "other apex pages are never touched", %{conn: conn, store: store} do
      _ = with_custom_domain!(store, "hotdeals.africa")

      for path <- ["/", "/pricing", "/stores", "/blog"] do
        refute call(conn, "makola.io", path).halted, "#{path} should not redirect"
      end
    end

    test "the custom domain itself never redirects", %{conn: conn, store: store} do
      _ = with_custom_domain!(store, "hotdeals.africa")
      refute call(conn, "hotdeals.africa", "/products").halted
    end
  end

  describe "Search Console coverage" do
    # The GSC property is sc-domain:makola.io, a Domain property — it covers
    # the apex and every *.makola.io subdomain, but NOT a merchant's own
    # domain. Without this being explicit, a merchant on a custom domain shows
    # zero search traffic and it reads as "no one is finding me".
    test "the platform property covers the apex and store subdomains" do
      Application.put_env(:emakola, :gsc_site_url, "sc-domain:makola.io")
      on_exit(fn -> Application.delete_env(:emakola, :gsc_site_url) end)

      assert SearchConsoleCoverage.covered?("makola.io")
      assert SearchConsoleCoverage.covered?("hotdeals-africa.makola.io")
    end

    test "it does not cover a merchant's own domain" do
      Application.put_env(:emakola, :gsc_site_url, "sc-domain:makola.io")
      on_exit(fn -> Application.delete_env(:emakola, :gsc_site_url) end)

      refute SearchConsoleCoverage.covered?("hotdeals.africa")
      refute SearchConsoleCoverage.covered?("www.hotdeals.africa")
    end

    test "a store with a custom domain is reported as uncovered", %{store: store} do
      Application.put_env(:emakola, :gsc_site_url, "sc-domain:makola.io")
      on_exit(fn -> Application.delete_env(:emakola, :gsc_site_url) end)

      refute SearchConsoleCoverage.store_uncovered_host(store.slug)

      _ = with_custom_domain!(store, "hotdeals.africa")

      assert SearchConsoleCoverage.store_uncovered_host(store.slug) == "hotdeals.africa"
    end

    test "nothing is claimed as covered when GSC is not configured" do
      Application.delete_env(:emakola, :gsc_site_url)
      refute SearchConsoleCoverage.covered?("makola.io")
    end
  end
end
