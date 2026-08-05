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
    refute Map.has_key?(attrs, "token")
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
    # AshJsonApi post controller always returns 201 regardless of insert vs upsert
    assert resp1.status == 201
    %{"data" => %{"id" => id1}} = Jason.decode!(resp1.resp_body)

    resp2 = post(conn, "/api/v1/device_tokens", body)
    assert resp2.status == 201
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
    # AshJsonApi delete controller renders 200 with the deleted record body
    assert del_conn.status == 200
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
    # bulk_destroy silently skips unauthorized rows -> empty BulkResult ->
    # AshJsonApi treats empty result as not-found -> 404
    assert del_conn.status == 404

    assert Ash.get!(Emakola.Notifications.DeviceToken, dt.id,
             authorize?: false,
             tenant: store.id
           )
  end

  test "invalid platform value returns 400", %{conn: conn} do
    conn =
      post(conn, "/api/v1/device_tokens", %{
        "data" => %{
          "type" => "device_token",
          "attributes" => %{"platform" => "windows", "token" => "fcm-bad-platform"}
        }
      })

    # Ash atom cast fails for unknown atoms; AshJsonApi maps :invalid -> 400
    assert conn.status == 400
  end

  test "POST without x-store-id header returns 403", %{conn: conn} do
    bare_conn =
      conn
      |> delete_req_header("x-store-id")

    bare_conn =
      post(bare_conn, "/api/v1/device_tokens", %{
        "data" => %{
          "type" => "device_token",
          "attributes" => %{"platform" => "android", "token" => "fcm-no-tenant"}
        }
      })

    # ApiTenant plug halts with 403 when x-store-id is absent
    assert bare_conn.status == 403
  end
end
