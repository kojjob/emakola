defmodule EmakolaWeb.Api.OpenApiTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  test "GET /api/v1/open_api returns a spec covering orders and device tokens", %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store.id)
      |> get("/api/v1/open_api")

    body = response(conn, 200)
    assert %{"openapi" => _, "paths" => paths} = Jason.decode!(body)

    path_keys = Map.keys(paths)
    assert Enum.any?(path_keys, &String.contains?(&1, "orders"))
    assert Enum.any?(path_keys, &String.contains?(&1, "device_tokens"))
  end
end
