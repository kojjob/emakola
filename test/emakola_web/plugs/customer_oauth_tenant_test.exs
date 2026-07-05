defmodule EmakolaWeb.Plugs.CustomerOAuthTenantTest do
  use EmakolaWeb.ConnCase, async: true

  alias EmakolaWeb.Plugs.CustomerOAuthTenant

  setup %{conn: conn} do
    {:ok, conn: Plug.Test.init_test_session(conn, %{})}
  end

  test "request phase resolves the store, stashes it, and sets the tenant", %{conn: conn} do
    {_merchant, store} = Emakola.Factory.create_merchant_with_store!()

    conn =
      conn
      |> Map.put(:path_info, ["oauth", "customer", "google"])
      |> Map.put(:params, %{"store_slug" => store.slug})
      |> CustomerOAuthTenant.call([])

    assert get_session(conn, "customer_oauth_store_id") == store.id
    assert CustomerOAuthTenant.store_slug(conn) == store.slug
    assert Ash.PlugHelpers.get_tenant(conn) == store.id
  end

  test "callback phase sets the tenant from the stashed store", %{conn: conn} do
    conn =
      conn
      |> put_session("customer_oauth_store_id", "store-abc")
      |> Map.put(:path_info, ["oauth", "customer", "google", "callback"])
      |> Map.put(:params, %{})
      |> CustomerOAuthTenant.call([])

    assert Ash.PlugHelpers.get_tenant(conn) == "store-abc"
  end

  test "is a no-op on merchant OAuth routes", %{conn: conn} do
    conn =
      conn
      |> Map.put(:path_info, ["oauth", "merchant", "google"])
      |> Map.put(:params, %{"store_slug" => "anything"})
      |> CustomerOAuthTenant.call([])

    assert is_nil(Ash.PlugHelpers.get_tenant(conn))
    assert is_nil(get_session(conn, "customer_oauth_store_id"))
  end
end
