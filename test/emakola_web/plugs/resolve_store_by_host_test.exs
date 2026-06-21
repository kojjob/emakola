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
             ["http://localhost:4000/@sub-shop/products?color=red"]
  end

  test "redirects the root path to the bare store URL (no trailing slash)", %{store: store} do
    claim!(store, "sub-shop.makola.io")

    conn = ResolveStoreByHost.call(conn_for("sub-shop.makola.io", "/"), @opts)

    assert Plug.Conn.get_resp_header(conn, "location") == ["http://localhost:4000/@sub-shop"]
  end

  test "serve-in-place rewrites the path to the /@:slug subfolder", %{store: store} do
    claim!(store, "sub-shop.makola.io", %{serve_in_place?: true})

    conn = ResolveStoreByHost.call(conn_for("sub-shop.makola.io", "/products"), @opts)

    refute conn.halted
    assert conn.path_info == ["@sub-shop", "products"]
  end

  test "serve-in-place does not double-prefix an internal /@:slug path", %{store: store} do
    claim!(store, "sub-shop.makola.io", %{serve_in_place?: true})

    conn = ResolveStoreByHost.call(conn_for("sub-shop.makola.io", "/@sub-shop/cart"), @opts)

    refute conn.halted
    assert conn.path_info == ["@sub-shop", "cart"]
  end

  test "passes an unknown subdomain through" do
    conn = ResolveStoreByHost.call(conn_for("ghost.makola.io", "/"), @opts)
    refute conn.halted
    assert conn.path_info == []
  end
end
