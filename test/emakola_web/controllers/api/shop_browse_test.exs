defmodule EmakolaWeb.Api.ShopBrowseTest do
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  setup %{conn: conn} do
    conn =
      conn
      |> put_unique_peer_ip()
      |> put_req_header("accept", "application/vnd.api+json")

    {:ok, conn: conn}
  end

  describe "GET /api/v1/shop/:store_slug/products" do
    test "returns only the store's ACTIVE products", %{conn: conn} do
      store = create_store!(%{slug: "pilot"})
      active = create_product!(store, %{status: :active})
      _draft = create_product!(store, %{status: :draft})
      _archived = create_product!(store, %{status: :archived})

      conn = get(conn, "/api/v1/shop/pilot/products")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])

      assert ids == [active.id]
      assert [%{"type" => "product"}] = data
    end

    test "404 for an unknown store slug (plug fail-closed)", %{conn: conn} do
      conn = get(conn, "/api/v1/shop/does-not-exist/products")

      assert conn.status == 404
    end

    test "returns ONLY store-a's products when store-b also has active products", %{conn: conn} do
      store_a = create_store!(%{slug: "store-a"})
      store_b = create_store!(%{slug: "store-b"})

      a_product = create_product!(store_a, %{status: :active})
      b_product = create_product!(store_b, %{status: :active})

      conn = get(conn, "/api/v1/shop/store-a/products")

      assert %{"data" => data} = json_response(conn, 200)
      ids = Enum.map(data, & &1["id"])

      assert a_product.id in ids
      refute b_product.id in ids
      assert ids == [a_product.id]
    end
  end

  describe "GET /api/v1/shop/:store_slug/products/:id" do
    test "returns the product with included variants and images", %{conn: conn} do
      store = create_store!(%{slug: "pilot"})
      product = create_product!(store, %{status: :active})
      variant = create_variant!(product, store)
      image = create_image!(product, store)

      conn = get(conn, "/api/v1/shop/pilot/products/#{product.id}?include=variants,images")

      assert %{"data" => %{"id" => id, "type" => "product"}, "included" => included} =
               json_response(conn, 200)

      assert id == product.id

      included_ids = Enum.map(included, & &1["id"])
      assert variant.id in included_ids
      assert image.id in included_ids
    end

    test "404 for a draft product id", %{conn: conn} do
      store = create_store!(%{slug: "pilot"})
      draft = create_product!(store, %{status: :draft})

      conn = get(conn, "/api/v1/shop/pilot/products/#{draft.id}")

      assert conn.status == 404
    end
  end

  test "GET /api/v1/shop with no slug → 404 (fail-closed, no tenantless leak)", %{conn: conn} do
    conn = conn |> put_unique_peer_ip() |> get("/api/v1/shop")
    assert conn.status in [404]
  end

  describe "GET /api/v1/shop/:store_slug" do
    test "returns the store info", %{conn: conn} do
      store = create_store!(%{slug: "pilot", name: "Pilot Store", currency: "GHS"})

      conn = get(conn, "/api/v1/shop/pilot")

      assert %{"data" => %{"type" => "store", "id" => id, "attributes" => attrs}} =
               json_response(conn, 200)

      assert id == store.id
      assert attrs["name"] == "Pilot Store"
      assert attrs["slug"] == "pilot"
      assert attrs["currency"] == "GHS"
    end
  end
end
