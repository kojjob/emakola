defmodule EmakolaWeb.Plugs.ApiTenantTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  alias EmakolaWeb.Plugs.ApiTenant

  defp call_with_actor(conn, merchant) do
    conn
    |> Ash.PlugHelpers.set_actor(merchant)
    |> ApiTenant.call(ApiTenant.init([]))
  end

  test "member store id sets the Ash tenant", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()

    conn =
      conn
      |> put_req_header("x-store-id", store.id)
      |> call_with_actor(merchant)

    refute conn.halted
    assert Ash.PlugHelpers.get_tenant(conn) == store.id
  end

  test "missing header → 403", %{conn: conn} do
    {merchant, _store} = create_merchant_with_store!()
    conn = call_with_actor(conn, merchant)

    assert conn.halted
    assert conn.status == 403
    assert %{"errors" => [%{"status" => "403"}]} = Jason.decode!(conn.resp_body)
  end

  test "store the merchant is NOT a member of → 403", %{conn: conn} do
    {merchant, _own_store} = create_merchant_with_store!()
    other_store = create_store!()

    conn =
      conn
      |> put_req_header("x-store-id", other_store.id)
      |> call_with_actor(merchant)

    assert conn.halted
    assert conn.status == 403
  end

  test "non-UUID header → 403", %{conn: conn} do
    {merchant, _store} = create_merchant_with_store!()

    conn =
      conn
      |> put_req_header("x-store-id", "not-a-uuid")
      |> call_with_actor(merchant)

    assert conn.halted
    assert conn.status == 403
  end

  test "no actor on conn → 403", %{conn: conn} do
    {_merchant, store} = create_merchant_with_store!()

    conn =
      conn
      |> put_req_header("x-store-id", store.id)
      |> ApiTenant.call(ApiTenant.init([]))

    assert conn.halted
    assert conn.status == 403
  end
end
