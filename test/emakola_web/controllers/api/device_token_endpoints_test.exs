defmodule EmakolaWeb.Api.DeviceTokenEndpointsTest do
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

    {:ok, conn: conn, merchant: merchant, store: store}
  end

  test "POST /api/v1/device_tokens registers a device", %{conn: conn} do
    conn =
      post(conn, "/api/v1/device_tokens", %{
        "data" => %{
          "type" => "device_token",
          "attributes" => %{"platform" => "android", "token" => "fcm-abc-123"}
        }
      })

    assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 201)
    assert is_binary(id)
    assert attrs["token"] == "fcm-abc-123"
    assert attrs["platform"] == "android"
  end

  test "re-registering the same token returns the same row (upsert)", %{conn: conn} do
    body = %{
      "data" => %{
        "type" => "device_token",
        "attributes" => %{"platform" => "ios", "token" => "fcm-same"}
      }
    }

    resp1 = post(conn, "/api/v1/device_tokens", body)
    assert resp1.status in [200, 201]
    %{"data" => %{"id" => id1}} = Jason.decode!(resp1.resp_body)

    resp2 = post(conn, "/api/v1/device_tokens", body)
    assert resp2.status in [200, 201]
    %{"data" => %{"id" => id2}} = Jason.decode!(resp2.resp_body)

    assert id1 == id2
  end

  test "DELETE /api/v1/device_tokens/:id unregisters", %{conn: conn} do
    resp =
      post(conn, "/api/v1/device_tokens", %{
        "data" => %{
          "type" => "device_token",
          "attributes" => %{"platform" => "android", "token" => "fcm-del"}
        }
      })

    %{"data" => %{"id" => id}} = Jason.decode!(resp.resp_body)

    del_conn = delete(conn, "/api/v1/device_tokens/#{id}")
    assert del_conn.status in [200, 204]
  end

  test "merchant cannot delete another merchant's device token", %{conn: conn, store: store} do
    other = create_merchant!()
    create_store_membership!(other, store, :staff)

    dt =
      Emakola.Notifications.DeviceToken
      |> Ash.Changeset.for_create(:register, %{platform: :android, token: "other-token"},
        actor: other,
        tenant: store.id
      )
      |> Ash.create!()

    del_conn = delete(conn, "/api/v1/device_tokens/#{dt.id}")
    assert del_conn.status in [403, 404]

    assert Ash.get!(Emakola.Notifications.DeviceToken, dt.id,
             authorize?: false,
             tenant: store.id
           )
  end
end
