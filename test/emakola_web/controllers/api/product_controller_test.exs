defmodule EmakolaWeb.Api.ProductControllerTest do
  @moduledoc """
  Merchant product-write endpoints — the API behind the mobile app's
  photo-first bulk add.

  Multi-tenant isolation is the point of most of these: `store_id` is derived
  from the X-Store-ID tenant and must never be honoured from the request body.
  """
  use EmakolaWeb.ConnCase, async: true

  import Emakola.Factory

  defp authed(conn, merchant, store) do
    {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

    conn
    |> put_unique_peer_ip()
    |> put_req_header("authorization", "Bearer #{pair.access_token}")
    |> put_req_header("x-store-id", store.id)
  end

  defp stub_storage do
    Mox.stub(Emakola.StorageMock, :upload, fn _binary, path, _opts ->
      {:ok, "https://cdn.example.com/#{path}"}
    end)
  end

  defp upload(filename, content_type, binary) do
    path = Path.join(System.tmp_dir!(), "#{Ecto.UUID.generate()}-#{filename}")
    File.write!(path, binary)
    on_exit(fn -> File.rm(path) end)
    %Plug.Upload{path: path, filename: filename, content_type: content_type}
  end

  describe "POST /api/v1/products" do
    test "creates a sellable product with a default variant", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products", %{"title" => "Shea body butter", "price" => 12_150})

      assert %{"data" => data} = json_response(conn, 201)
      assert data["title"] == "Shea body butter"
      assert data["status"] == "active"
      assert is_binary(data["id"]) and is_binary(data["slug"])

      # A price makes it immediately sellable: one default variant, untracked.
      assert %{"id" => variant_id, "price" => 12_150} = data["default_variant"]
      assert is_binary(variant_id)

      variant = Ash.get!(Emakola.Catalog.Variant, variant_id, authorize?: false)
      assert variant.store_id == store.id
      assert variant.track_inventory == false
    end

    test "without a price the product stays a draft", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products", %{"title" => "Not priced yet"})

      assert %{"data" => data} = json_response(conn, 201)
      # Activation requires a variant, so a product with no price cannot go live.
      assert data["status"] == "draft"
      assert data["default_variant"] == nil
    end

    test "a blank title is rejected", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products", %{"title" => "   "})

      assert %{"errors" => [%{"status" => "422"}]} = json_response(conn, 422)
    end

    test "store_id in the body is ignored, not honoured", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      victim = create_store!()

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products", %{
          "title" => "Planted elsewhere",
          "price" => 5000,
          "store_id" => victim.id
        })

      assert %{"data" => data} = json_response(conn, 201)

      product = Ash.get!(Emakola.Catalog.Product, data["id"], authorize?: false)
      assert product.store_id == store.id
      refute product.store_id == victim.id
    end

    test "403 without a store header", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      {:ok, pair} = Emakola.Accounts.ApiTokens.issue_pair(merchant)

      conn =
        conn
        |> put_unique_peer_ip()
        |> put_req_header("authorization", "Bearer #{pair.access_token}")
        |> post(~p"/api/v1/products", %{"title" => "No tenant"})

      assert %{"errors" => [%{"status" => "403"}]} = json_response(conn, 403)
    end

    test "403 for a store the merchant does not belong to", %{conn: conn} do
      {merchant, _store} = create_merchant_with_store!()
      other = create_store!()

      conn =
        conn
        |> authed(merchant, other)
        |> post(~p"/api/v1/products", %{"title" => "Someone else's store"})

      assert %{"errors" => [%{"status" => "403"}]} = json_response(conn, 403)
    end

    test "401 without a token", %{conn: conn} do
      conn =
        conn
        |> put_unique_peer_ip()
        |> post(~p"/api/v1/products", %{"title" => "Anonymous"})

      assert %{"errors" => [%{"status" => "401"}]} = json_response(conn, 401)
    end
  end

  describe "POST /api/v1/products/:id/variants" do
    test "adds a variant to the merchant's product", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{product.id}/variants", %{
          "price" => 8000,
          "sku" => "SHEA-LG"
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert data["price"] == 8000
      assert data["sku"] == "SHEA-LG"

      variant = Ash.get!(Emakola.Catalog.Variant, data["id"], authorize?: false)
      assert variant.store_id == store.id
      assert variant.product_id == product.id
    end

    test "cannot attach a variant to another store's product", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      other_store = create_store!()
      foreign_product = create_product!(other_store)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{foreign_product.id}/variants", %{"price" => 8000})

      assert %{"errors" => [%{"status" => "404"}]} = json_response(conn, 404)
    end

    test "a missing price is rejected", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{product.id}/variants", %{"sku" => "NO-PRICE"})

      assert %{"errors" => [%{"status" => "422"}]} = json_response(conn, 422)
    end
  end

  describe "POST /api/v1/products/:id/images" do
    test "uploads an image and attaches it to the product", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      product = create_product!(store)
      stub_storage()

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{product.id}/images", %{
          "file" => upload("shea.jpg", "image/jpeg", "not-really-a-jpeg-but-bytes")
        })

      assert %{"data" => data} = json_response(conn, 201)
      assert is_binary(data["url"])
      assert data["content_type"] == "image/jpeg"

      image = Ash.get!(Emakola.Catalog.Image, data["id"], authorize?: false)
      assert image.store_id == store.id
      assert image.product_id == product.id
    end

    test "rejects a content type the catalog does not accept", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{product.id}/images", %{
          "file" => upload("evil.svg", "image/svg+xml", "<svg/>")
        })

      assert %{"errors" => [%{"status" => "422", "code" => "unsupported_content_type"}]} =
               json_response(conn, 422)
    end

    test "rejects a file over the size cap before uploading it", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      oversized = :binary.copy("x", 10_000_001)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{product.id}/images", %{
          "file" => upload("huge.jpg", "image/jpeg", oversized)
        })

      assert %{"errors" => [%{"status" => "422", "code" => "file_too_large"}]} =
               json_response(conn, 422)
    end

    test "cannot attach an image to another store's product", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      other_store = create_store!()
      foreign_product = create_product!(other_store)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{foreign_product.id}/images", %{
          "file" => upload("shea.jpg", "image/jpeg", "bytes")
        })

      assert %{"errors" => [%{"status" => "404"}]} = json_response(conn, 404)
    end

    test "a request without a file is rejected", %{conn: conn} do
      {merchant, store} = create_merchant_with_store!()
      product = create_product!(store)

      conn =
        conn
        |> authed(merchant, store)
        |> post(~p"/api/v1/products/#{product.id}/images", %{})

      assert %{"errors" => [%{"status" => "422", "code" => "missing_file"}]} =
               json_response(conn, 422)
    end
  end
end
