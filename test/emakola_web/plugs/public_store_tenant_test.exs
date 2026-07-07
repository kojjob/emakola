defmodule EmakolaWeb.Plugs.PublicStoreTenantTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.Plugs.PublicStoreTenant

  defp call(conn, slug) do
    %{conn | path_params: Map.put(conn.path_params, "store_slug", slug)}
    |> PublicStoreTenant.call(PublicStoreTenant.init([]))
  end

  test "active store slug sets the Ash tenant + assigns the store", %{conn: conn} do
    {_merchant, store} = create_merchant_with_store!(%{slug: "pilot-shop"})
    conn = call(conn, "pilot-shop")

    refute conn.halted
    assert Ash.PlugHelpers.get_tenant(conn) == store.id
    assert conn.assigns[:shop_store].id == store.id
  end

  test "unknown slug → 404 JSON:API error, halted, NO tenant set", %{conn: conn} do
    conn = call(conn, "does-not-exist")

    assert conn.halted
    assert conn.status == 404
    assert %{"errors" => [%{"status" => "404"}]} = Jason.decode!(conn.resp_body)
    assert is_nil(Ash.PlugHelpers.get_tenant(conn))
  end

  test "inactive store → 404, halted, no tenant (don't serve inactive stores)", %{conn: conn} do
    create_store!(%{slug: "closed-shop", active: false})
    conn = call(conn, "closed-shop")

    assert conn.halted
    assert conn.status == 404
    assert is_nil(Ash.PlugHelpers.get_tenant(conn))
  end

  test "missing store_slug param → 404, halted, no tenant", %{conn: conn} do
    conn = PublicStoreTenant.call(conn, PublicStoreTenant.init([]))

    assert conn.halted
    assert conn.status == 404
    assert is_nil(Ash.PlugHelpers.get_tenant(conn))
  end
end
