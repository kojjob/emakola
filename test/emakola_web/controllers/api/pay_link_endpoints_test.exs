defmodule EmakolaWeb.Api.PayLinkEndpointsTest do
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

  # No PayLink factory helper exists yet (see task-8-report.md) — a local,
  # tenant-scoped create keeps the cross-store tests below from repeating
  # the same 5-line changeset.
  defp create_pay_link!(store, attrs \\ %{}) do
    default = %{store_id: store.id, type: :custom, title: "Deal", amount: 25_000}

    Emakola.Orders.PayLink
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)), tenant: store.id)
    |> Ash.create!(authorize?: false)
  end

  describe "POST /api/v1/pay_links" do
    test "creates a custom link", %{conn: conn, store: store} do
      conn =
        post(conn, "/api/v1/pay_links", %{
          "data" => %{
            "type" => "pay_link",
            "attributes" => %{
              "store_id" => store.id,
              "type" => "custom",
              "title" => "Deal",
              "amount" => 25_000
            }
          }
        })

      assert %{"data" => %{"attributes" => attrs}} = json_response(conn, 201)
      assert attrs["code"] =~ ~r/^[a-z2-7]{8}$/
      assert attrs["status"] == "active"
    end

    # store_id is a public, accepted attribute on :create (Task 3's design —
    # internal callers pass it explicitly, e.g. the admin LiveView). Ash's
    # attribute-multitenancy force-sets it from the X-Store-ID tenant right
    # before insert, so a body attribute spoofing a different store can never
    # win — pin that so this route can't become a cross-tenant write.
    test "a spoofed store_id attribute cannot escape the X-Store-ID tenant", %{
      conn: conn,
      store: store
    } do
      {_other_merchant, other_store} = create_merchant_with_store!()

      conn =
        post(conn, "/api/v1/pay_links", %{
          "data" => %{
            "type" => "pay_link",
            "attributes" => %{
              "store_id" => other_store.id,
              "type" => "custom",
              "title" => "Deal",
              "amount" => 25_000
            }
          }
        })

      assert %{"data" => %{"id" => id}} = json_response(conn, 201)

      created = Ash.get!(Emakola.Orders.PayLink, id, authorize?: false, tenant: store.id)
      assert created.store_id == store.id
    end
  end

  describe "GET /api/v1/pay_links" do
    test "scopes to X-Store-ID: own link included, other store's link absent",
         %{conn: conn, store: store} do
      {_other_merchant, other_store} = create_merchant_with_store!()
      pay_link = create_pay_link!(store)
      foreign = create_pay_link!(other_store)

      conn = get(conn, "/api/v1/pay_links")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])
      assert pay_link.id in ids
      refute foreign.id in ids
    end

    test "requests without X-Store-ID are rejected", %{conn: conn} do
      conn = delete_req_header(conn, "x-store-id")
      # ApiTenant halts with a uniform 403 for a missing/inaccessible store header.
      assert json_response(get(conn, "/api/v1/pay_links"), 403)
    end
  end

  describe "GET /api/v1/pay_links/:id" do
    test "returns the pay link", %{conn: conn, store: store} do
      pay_link = create_pay_link!(store)

      conn = get(conn, "/api/v1/pay_links/#{pay_link.id}")

      assert %{"data" => %{"id" => id, "attributes" => attrs}} = json_response(conn, 200)
      assert id == pay_link.id
      assert attrs["status"] == "active"
    end

    test "fetching a foreign pay link id under own tenant → 404 (no existence leak)",
         %{conn: conn} do
      {_other_merchant, other_store} = create_merchant_with_store!()
      foreign = create_pay_link!(other_store)

      conn = get(conn, "/api/v1/pay_links/#{foreign.id}")
      assert conn.status == 404
    end
  end

  describe "PATCH /api/v1/pay_links/:id/cancel" do
    test "cancels an active link", %{conn: conn, store: store} do
      pay_link = create_pay_link!(store)

      conn =
        patch(conn, "/api/v1/pay_links/#{pay_link.id}/cancel", %{
          "data" => %{"type" => "pay_link", "id" => pay_link.id, "attributes" => %{}}
        })

      assert %{"data" => %{"attributes" => attrs}} = json_response(conn, 200)
      assert attrs["status"] == "cancelled"
    end

    test "cancelling a foreign pay link under own tenant fails and does not mutate",
         %{conn: conn} do
      {_other_merchant, other_store} = create_merchant_with_store!()
      foreign = create_pay_link!(other_store)

      conn =
        patch(conn, "/api/v1/pay_links/#{foreign.id}/cancel", %{
          "data" => %{"type" => "pay_link", "id" => foreign.id, "attributes" => %{}}
        })

      assert conn.status in [403, 404]

      reloaded =
        Ash.get!(Emakola.Orders.PayLink, foreign.id, authorize?: false, tenant: other_store.id)

      assert reloaded.status == :active
    end
  end
end
