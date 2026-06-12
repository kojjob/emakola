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
      # Both orders may share inserted_at second-precision. Ash appends the primary
      # key as a tiebreaker, so ordering is deterministic but not creation-ordered
      # within equal timestamps. Check set membership instead.
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

    test "rejects arbitrary attribute filter", %{conn: conn, store: store} do
      _order = create_order!(store)

      conn = get(conn, "/api/v1/orders?filter[notes][contains]=x")

      assert conn.status in [400, 422]
    end

    test "keyset cursor advances through pages", %{conn: conn, store: store} do
      # Create 3 orders; inserted_at + id sort ensures stable order
      order1 = create_order!(store)
      order2 = create_order!(store)
      order3 = create_order!(store)

      # Page 1: newest-first, limit 2
      resp1 = get(conn, "/api/v1/orders?page[limit]=2")
      assert %{"data" => page1_data, "links" => links1} = json_response(resp1, 200)
      assert length(page1_data) == 2

      # Cursor lives in links.next as page[after]=<encoded_cursor>
      assert is_binary(links1["next"]), "expected a next link for page 1"
      %URI{path: next_path, query: next_query} = URI.parse(links1["next"])
      next_url = "#{next_path}?#{next_query}"

      page1_ids = Enum.map(page1_data, & &1["id"])

      # Page 2: follow the next link
      resp2 = get(conn, next_url)
      assert %{"data" => page2_data, "links" => links2} = json_response(resp2, 200)
      assert length(page2_data) == 1

      # No further pages
      assert is_nil(links2["next"]) or links2["next"] == nil

      page2_ids = Enum.map(page2_data, & &1["id"])

      # No overlap between pages
      assert MapSet.disjoint?(MapSet.new(page1_ids), MapSet.new(page2_ids)),
             "expected no overlap between pages"

      # All three orders appear across both pages
      all_ids = page1_ids ++ page2_ids
      assert order1.id in all_ids
      assert order2.id in all_ids
      assert order3.id in all_ids
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

    test "400 for invalid uuid", %{conn: conn} do
      conn = get(conn, "/api/v1/orders/not-a-uuid")
      assert conn.status == 400
    end
  end
end
