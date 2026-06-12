defmodule EmakolaWeb.Api.OrderTransitionsTest do
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
      |> put_req_header("content-type", "application/vnd.api+json")

    {:ok, conn: conn, store: store}
  end

  defp patch_transition(conn, order, transition, attributes \\ %{}) do
    patch(conn, "/api/v1/orders/#{order.id}/#{transition}", %{
      "data" => %{"type" => "order", "id" => order.id, "attributes" => attributes}
    })
  end

  test "confirm: pending → confirmed", %{conn: conn, store: store} do
    order = create_order!(store)

    conn = patch_transition(conn, order, "confirm")

    assert %{"data" => %{"attributes" => %{"status" => "confirmed"}}} =
             json_response(conn, 200)
  end

  test "full lifecycle: confirm → start_processing → mark_shipped → mark_delivered",
       %{conn: conn, store: store} do
    order = create_order!(store)

    for {transition, expected} <- [
          {"confirm", "confirmed"},
          {"start_processing", "processing"},
          {"mark_shipped", "shipped"},
          {"mark_delivered", "delivered"}
        ] do
      conn = patch_transition(conn, order, transition)
      assert %{"data" => %{"attributes" => %{"status" => ^expected}}} = json_response(conn, 200)
    end
  end

  test "cancel a pending order", %{conn: conn, store: store} do
    order = create_order!(store)

    conn = patch_transition(conn, order, "cancel")
    assert %{"data" => %{"attributes" => %{"status" => "cancelled"}}} = json_response(conn, 200)
  end

  test "mark_shipped accepts and persists tracking_number", %{conn: conn, store: store} do
    order = create_order!(store, %{status: :processing})

    conn = patch_transition(conn, order, "mark_shipped", %{"tracking_number" => "TRK-12345"})

    assert %{
             "data" => %{
               "attributes" => %{"status" => "shipped", "tracking_number" => "TRK-12345"}
             }
           } = json_response(conn, 200)
  end

  # The 400 + "invalid_attribute" pair is the API contract the mobile client
  # branches on when a retried transition has already been applied — pin it.
  test "invalid transition (deliver a pending order) → 400, status unchanged",
       %{conn: conn, store: store} do
    order = create_order!(store)

    conn = patch_transition(conn, order, "mark_delivered")
    assert %{"errors" => [%{"code" => "invalid_attribute"}]} = json_response(conn, 400)

    reloaded = Ash.get!(Emakola.Orders.Order, order.id, authorize?: false, tenant: store.id)
    assert reloaded.status == :pending
  end
end
