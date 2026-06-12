defmodule EmakolaWeb.Api.OrderEndpointsTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    {merchant, store} = create_merchant_with_store!()
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("authorization", "Bearer #{pair.access_token}")
      |> put_req_header("x-store-id", store.id)
      |> put_req_header("accept", "application/vnd.api+json")

    {:ok, conn: conn, merchant: merchant, store: store}
  end

  describe "GET /api/v1/orders" do
    test "lists the store's orders", %{conn: conn, store: store} do
      order1 = create_order!(store)
      order2 = create_order!(store)

      conn = get(conn, "/api/v1/orders")

      assert %{"data" => data} = json_response(conn, 200)
      # Both orders may share inserted_at second-precision — check set membership.
      # Ordering stability depends on inserted_at precision; UUIDs are random so
      # id: :desc is not a reliable tiebreaker. Decision: relax to set-equality.
      ids = Enum.map(data, & &1["id"])
      assert order1.id in ids
      assert order2.id in ids
      assert [%{"type" => "order", "attributes" => attrs} | _] = data
      assert attrs["order_number"] =~ "ORD-"
      assert attrs["status"] == "pending"
    end

    test "filters by status", %{conn: conn, store: store} do
      _pending = create_order!(store)
      confirmed = create_order!(store, %{status: :confirmed})

      conn = get(conn, "/api/v1/orders?filter[status]=confirmed")

      assert %{"data" => [%{"id" => id}]} = json_response(conn, 200)
      assert id == confirmed.id
    end

    test "paginates", %{conn: conn, store: store} do
      for _ <- 1..3, do: create_order!(store)

      conn = get(conn, "/api/v1/orders?page[limit]=2")
      assert %{"data" => data} = json_response(conn, 200)
      assert length(data) == 2
    end

    test "401 without token", %{store: store} do
      conn =
        build_conn()
        |> put_unique_peer_ip()
        |> put_req_header("x-store-id", store.id)
        |> get("/api/v1/orders")

      assert conn.status == 401
    end
  end

  describe "GET /api/v1/orders/:id" do
    test "returns the order", %{conn: conn, store: store} do
      order = create_order!(store)

      conn = get(conn, "/api/v1/orders/#{order.id}")

      assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 200)
      assert id == order.id
      assert attrs["currency"] == "GHS"
    end

    test "404 for unknown id", %{conn: conn} do
      conn = get(conn, "/api/v1/orders/#{Ash.UUID.generate()}")
      assert conn.status == 404
    end
  end
end
