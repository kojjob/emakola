defmodule EmakolaWeb.Api.TenantIsolationTest do
  @moduledoc """
  Multi-tenant isolation guarantees for the mobile API. Every test here is a
  security invariant: merchant A must never read or mutate store B's data,
  even with a valid token and a forged X-Store-ID.
  """
  use EmakolaWeb.ConnCase, async: true

  @moduletag :integration

  import Emakola.Factory

  setup %{conn: conn} do
    {merchant_a, store_a} = create_merchant_with_store!()
    {merchant_b, store_b} = create_merchant_with_store!()
    {:ok, pair_a} = Emakola.Accounts.ApiTokens.issue_pair(merchant_a)

    base =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair_a.access_token}")
      |> put_req_header("accept", "application/vnd.api+json")

    {:ok,
     conn: base,
     merchant_a: merchant_a,
     store_a: store_a,
     merchant_b: merchant_b,
     store_b: store_b}
  end

  test "forged X-Store-ID for a non-member store → 403", %{conn: conn, store_b: store_b} do
    conn = conn |> put_req_header("x-store-id", store_b.id) |> get("/api/v1/orders")
    assert conn.status == 403
  end

  test "own store list never contains another store's orders",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    _own = create_order!(store_a)
    foreign = create_order!(store_b)

    conn = conn |> put_req_header("x-store-id", store_a.id) |> get("/api/v1/orders")

    assert %{"data" => data} = json_response(conn, 200)
    refute foreign.id in Enum.map(data, & &1["id"])
  end

  test "fetching a foreign order id under own tenant → 404 (no existence leak)",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    foreign = create_order!(store_b)

    conn =
      conn
      |> put_req_header("x-store-id", store_a.id)
      |> get("/api/v1/orders/#{foreign.id}")

    assert conn.status == 404
  end

  test "transitioning a foreign order under own tenant fails and does not mutate",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    foreign = create_order!(store_b)

    conn =
      conn
      |> put_req_header("x-store-id", store_a.id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/v1/orders/#{foreign.id}/confirm", %{
        "data" => %{"type" => "order", "id" => foreign.id, "attributes" => %{}}
      })

    assert conn.status in [403, 404]

    reloaded =
      Ash.get!(Emakola.Orders.Order, foreign.id, authorize?: false, tenant: store_b.id)

    assert reloaded.status == :pending
  end

  test "merchant B's token cannot use store A's tenant",
       %{store_a: store_a, merchant_b: merchant_b} do
    {:ok, pair_b} = Emakola.Accounts.ApiTokens.issue_pair(merchant_b)

    conn =
      build_conn()
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair_b.access_token}")
      |> put_req_header("x-store-id", store_a.id)
      |> get("/api/v1/orders")

    assert conn.status == 403
  end

  test "expired-session hygiene: revoked token cannot list orders even with valid membership",
       %{conn: _conn, merchant_a: merchant_a, store_a: store_a} do
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant_a)
    :ok = Emakola.Accounts.ApiTokens.revoke(pair.access_token)

    conn =
      build_conn()
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store_a.id)
      |> get("/api/v1/orders")

    assert conn.status == 401
  end

  test "filter cannot escape the tenant: filter[store_id] for store B under tenant A returns nothing",
       %{conn: conn, store_a: store_a, store_b: store_b} do
    _own = create_order!(store_a)
    _foreign = create_order!(store_b)

    conn =
      conn
      |> put_req_header("x-store-id", store_a.id)
      |> get("/api/v1/orders?filter[store_id]=#{store_b.id}")

    # Either rejected outright or filtered to empty within tenant A — both safe.
    case conn.status do
      200 ->
        assert %{"data" => data} = Jason.decode!(conn.resp_body)
        assert data == []

      other ->
        assert other in [400, 403]
    end
  end
end
