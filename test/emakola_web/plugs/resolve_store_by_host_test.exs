defmodule EmakolaWeb.Plugs.ResolveStoreByHostTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias Emakola.Stores
  alias EmakolaWeb.Plugs.ResolveStoreByHost

  @opts ResolveStoreByHost.init(subdomain_base: "makola.io")

  setup do
    store = create_store!(%{name: "Sub Shop", slug: "sub-shop"})
    {:ok, store: store}
  end

  defp conn_for(host, path) do
    Phoenix.ConnTest.build_conn(:get, path) |> Map.put(:host, host)
  end

  defp claim!(store, host, attrs \\ %{}) do
    {:ok, _} =
      Stores.create_store_domain(Map.merge(%{store_id: store.id, host: host}, attrs),
        authorize?: false
      )
  end

  test "passes the apex host through" do
    conn = ResolveStoreByHost.call(conn_for("makola.io", "/"), @opts)
    refute conn.halted
    assert conn.path_info == []
  end

  test "passes through (ship-dark) when no subdomain base is configured", %{store: store} do
    claim!(store, "sub-shop.makola.io")

    conn =
      ResolveStoreByHost.call(
        conn_for("sub-shop.makola.io", "/products"),
        ResolveStoreByHost.init([])
      )

    refute conn.halted
  end

  test "301-redirects a subdomain to the apex subfolder by default, preserving path + query",
       %{store: store} do
    claim!(store, "sub-shop.makola.io")

    conn = ResolveStoreByHost.call(conn_for("sub-shop.makola.io", "/products?color=red"), @opts)

    assert conn.halted
    assert conn.status == 301

    assert Plug.Conn.get_resp_header(conn, "location") ==
             ["http://localhost:4000/s/sub-shop/products?color=red"]
  end

  test "redirects the root path to the bare store URL (no trailing slash)", %{store: store} do
    claim!(store, "sub-shop.makola.io")

    conn = ResolveStoreByHost.call(conn_for("sub-shop.makola.io", "/"), @opts)

    assert Plug.Conn.get_resp_header(conn, "location") == ["http://localhost:4000/s/sub-shop"]
  end

  # serve_in_place? domains are no longer rewritten here — the router host-routes
  # the storefront at root (ResolveStoreHost + the catch-all), so this plug passes
  # them through untouched, leaving conn.path_info as-is.
  test "passes a serve-in-place domain through (router host-routes it at root)", %{store: store} do
    claim!(store, "sub-shop.makola.io", %{serve_in_place?: true})

    conn = ResolveStoreByHost.call(conn_for("sub-shop.makola.io", "/products"), @opts)

    refute conn.halted
    assert conn.path_info == ["products"]
  end

  test "passes an unknown subdomain through" do
    conn = ResolveStoreByHost.call(conn_for("ghost.makola.io", "/"), @opts)
    refute conn.halted
    assert conn.path_info == []
  end

  # No StoreDomain row: the implicit <slug>.<base> subdomain is no longer rewritten
  # here. It passes through to the router, which host-routes it at root.
  test "passes an implicit <slug>.<base> subdomain through with no StoreDomain row",
       %{store: store} do
    conn = ResolveStoreByHost.call(conn_for("#{store.slug}.makola.io", "/products"), @opts)

    refute conn.halted
    assert conn.path_info == ["products"]
    refute conn.private[:emakola_on_store_subdomain?]
  end

  test "a reserved label passes through (never redirected to a subfolder)" do
    create_store!(%{name: "Admin Co", slug: "admin"})

    conn = ResolveStoreByHost.call(conn_for("admin.makola.io", "/"), @opts)

    refute conn.halted
    assert conn.path_info == []
  end

  # Note: store lifecycle enforcement (suspended/blocked/archived stores not
  # serving) lives at the StoreResolver.resolve/1 chokepoint that every host
  # path funnels through (the ResolveStoreFromHost / ResolveStore hooks), not in
  # this SEO-canonicalization plug. See store_resolver_test.exs and
  # storefront/store_lifecycle_access_test.exs.
end
