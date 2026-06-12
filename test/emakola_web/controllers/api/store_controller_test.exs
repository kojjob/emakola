defmodule EmakolaWeb.Api.StoreControllerTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  describe "GET /api/v1/stores" do
    test "lists only the merchant's stores with role", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      _other_store = create_store!()

      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn =
        conn
        |> put_unique_peer_ip()
        |> put_req_header("authorization", "Bearer #{pair.access_token}")
        |> get(~p"/api/v1/stores")

      assert %{"data" => [entry]} = json_response(conn, 200)
      assert entry["id"] == store.id
      assert entry["role"] == "owner"
      assert is_binary(entry["name"]) and is_binary(entry["slug"])
      assert entry["currency"] == "GHS"
    end

    test "merchant with two stores sees both", %{conn: conn} do
      {merchant, store_a} = create_merchant_with_store!()
      store_b = create_store!()
      create_store_membership!(merchant, store_b, :staff)

      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn =
        conn
        |> put_unique_peer_ip()
        |> put_req_header("authorization", "Bearer #{pair.access_token}")
        |> get(~p"/api/v1/stores")

      assert %{"data" => data} = json_response(conn, 200)
      assert Enum.sort(Enum.map(data, & &1["id"])) == Enum.sort([store_a.id, store_b.id])

      roles = Map.new(data, fn e -> {e["id"], e["role"]} end)
      assert roles[store_a.id] == "owner"
      assert roles[store_b.id] == "staff"
    end

    test "401 without a token", %{conn: conn} do
      conn = conn |> put_unique_peer_ip() |> get(~p"/api/v1/stores")
      assert %{"errors" => [%{"status" => "401"}]} = json_response(conn, 401)
    end
  end
end
