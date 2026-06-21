defmodule Emakola.Notifications.Channels.WhatsappCatalogTest do
  @moduledoc """
  Pins the contract for the real Meta Commerce HTTP client.

  Uses the same `:http_client` Application.put_env mock pattern as
  `Emakola.Notifications.Channels.SMSTest` so we never hit the real
  Meta Graph API in tests.
  """
  use ExUnit.Case, async: false

  alias Emakola.Notifications.Channels.WhatsappCatalog

  # ── Pure functions ──────────────────────────────────────────────

  describe "build_product_body/1" do
    test "formats price as major-units string with currency suffix" do
      body =
        WhatsappCatalog.build_product_body(%{
          retailer_id: "abc",
          name: "Tee",
          price_minor: 12_500,
          currency: "GHS",
          availability: :in_stock,
          url: "https://e.x/p/tee",
          image_url: "https://e.x/i.jpg"
        })

      assert body.price == "125.00 GHS"
      assert body.currency == "GHS"
    end

    test "pads cents to two digits" do
      body =
        WhatsappCatalog.build_product_body(%{
          retailer_id: "abc",
          name: "Tee",
          price_minor: 1205,
          currency: "GHS",
          availability: :in_stock,
          url: "https://e.x"
        })

      assert body.price == "12.05 GHS"
    end

    test "translates availability atom to Meta string" do
      in_stock =
        WhatsappCatalog.build_product_body(%{
          retailer_id: "a",
          name: "x",
          price_minor: 0,
          currency: "GHS",
          availability: :in_stock,
          url: "https://e.x"
        })

      out =
        WhatsappCatalog.build_product_body(%{
          retailer_id: "a",
          name: "x",
          price_minor: 0,
          currency: "GHS",
          availability: :out_of_stock,
          url: "https://e.x"
        })

      assert in_stock.availability == "in stock"
      assert out.availability == "out of stock"
    end

    test "drops nil keys (image_url not always present)" do
      body =
        WhatsappCatalog.build_product_body(%{
          retailer_id: "a",
          name: "x",
          price_minor: 0,
          currency: "GHS",
          availability: :in_stock,
          url: "https://e.x"
        })

      refute Map.has_key?(body, :image_url)
    end

    test "falls back to name when description nil" do
      body =
        WhatsappCatalog.build_product_body(%{
          retailer_id: "a",
          name: "Sneakers",
          description: nil,
          price_minor: 0,
          currency: "GHS",
          availability: :in_stock,
          url: "https://e.x"
        })

      assert body.description == "Sneakers"
    end
  end

  # ── HTTP behaviour ──────────────────────────────────────────────

  describe "upsert_product/3 with mocked HTTP" do
    setup do
      original_http = Application.get_env(:emakola, :http_client)
      original_cfg = Application.get_env(:emakola, WhatsappCatalog)

      Application.put_env(:emakola, :http_client, __MODULE__.MockHTTP)

      Application.put_env(:emakola, WhatsappCatalog,
        api_token: "test_token",
        graph_version: "v18.0"
      )

      on_exit(fn ->
        if original_http,
          do: Application.put_env(:emakola, :http_client, original_http),
          else: Application.delete_env(:emakola, :http_client)

        if original_cfg,
          do: Application.put_env(:emakola, WhatsappCatalog, original_cfg),
          else: Application.delete_env(:emakola, WhatsappCatalog)
      end)

      :ok
    end

    test "POSTs to /v18.0/{catalog_id}/products with bearer auth" do
      payload = valid_payload()

      assert {:ok, %{status: 200}} =
               WhatsappCatalog.upsert_product("CAT123", payload)

      assert_received {:catalog_post, url, headers, body}
      assert url =~ "/v18.0/CAT123/products"
      assert {"authorization", "Bearer test_token"} in headers
      assert body.retailer_id == payload.retailer_id
      assert body.price =~ "GHS"
    end

    test "rejects payload missing required keys" do
      payload = Map.delete(valid_payload(), :url)

      assert {:error, {:missing_keys, [:url]}} =
               WhatsappCatalog.upsert_product("CAT123", payload)
    end
  end

  describe "upsert_product/3 error path" do
    setup do
      Application.put_env(:emakola, :http_client, __MODULE__.ErrorHTTP)
      Application.put_env(:emakola, WhatsappCatalog, api_token: "x")

      on_exit(fn ->
        Application.delete_env(:emakola, :http_client)
        Application.delete_env(:emakola, WhatsappCatalog)
      end)

      :ok
    end

    test "returns {:error, %{status: 400}} on API rejection" do
      assert {:error, %{status: 400}} =
               WhatsappCatalog.upsert_product("CAT123", valid_payload())
    end
  end

  describe "delete_product/3" do
    setup do
      Application.put_env(:emakola, :http_client, __MODULE__.MockHTTP)
      Application.put_env(:emakola, WhatsappCatalog, api_token: "tok")

      on_exit(fn ->
        Application.delete_env(:emakola, :http_client)
        Application.delete_env(:emakola, WhatsappCatalog)
      end)

      :ok
    end

    test "DELETEs to /v18.0/{retailer_id}" do
      assert :ok = WhatsappCatalog.delete_product("CAT123", "ret-abc")
      assert_received {:catalog_delete, url, _headers}
      assert url =~ "/v18.0/ret-abc"
    end
  end

  describe "delete_product/3 with 404" do
    setup do
      Application.put_env(:emakola, :http_client, __MODULE__.NotFoundHTTP)
      Application.put_env(:emakola, WhatsappCatalog, api_token: "tok")

      on_exit(fn ->
        Application.delete_env(:emakola, :http_client)
        Application.delete_env(:emakola, WhatsappCatalog)
      end)

      :ok
    end

    test "treats 404 as success (already gone)" do
      assert :ok = WhatsappCatalog.delete_product("CAT123", "ret-abc")
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────

  defp valid_payload do
    %{
      retailer_id: "prod-uuid-123",
      name: "Kente Tee",
      description: "Cotton, slim fit",
      price_minor: 5_000,
      currency: "GHS",
      availability: :in_stock,
      image_url: "https://e.x/i.jpg",
      url: "https://e.x/@shop/products/kente-tee"
    }
  end

  defmodule MockHTTP do
    def post(url, opts) do
      send(
        self(),
        {:catalog_post, url, Keyword.fetch!(opts, :headers), Keyword.fetch!(opts, :json)}
      )

      {:ok, %{status: 200, body: %{"id" => "fb-cat-prod-id"}}}
    end

    def delete(url, opts) do
      send(self(), {:catalog_delete, url, Keyword.fetch!(opts, :headers)})
      {:ok, %{status: 200, body: %{"success" => true}}}
    end
  end

  defmodule ErrorHTTP do
    def post(_url, _opts), do: {:ok, %{status: 400, body: %{"error" => %{"message" => "bad"}}}}
  end

  defmodule NotFoundHTTP do
    def delete(_url, _opts), do: {:ok, %{status: 404, body: %{}}}
  end
end
