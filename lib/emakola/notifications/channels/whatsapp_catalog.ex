defmodule Emakola.Notifications.Channels.WhatsappCatalog do
  @moduledoc """
  Meta Commerce / WhatsApp Business Catalog client.

  Mirrors Emakola products into a merchant's WhatsApp Business Catalog
  via the Meta Graph API. Buyers browsing the catalog inside WhatsApp
  can tap-to-message the merchant about any product — the highest-
  conversion entry point for West African mobile commerce.

  ## Endpoints

      POST   https://graph.facebook.com/v18.0/{catalog_id}/products
      DELETE https://graph.facebook.com/v18.0/{retailer_id}

  Authenticated with the same `WHATSAPP_API_TOKEN` used by the
  notifications channel. Per-merchant catalog IDs live on
  `Store.whatsapp_catalog_id`.

  ## Configuration

      config :emakola, Emakola.Notifications.Channels.WhatsappCatalog,
        api_token: System.get_env("WHATSAPP_API_TOKEN"),
        graph_version: "v18.0"

  ## Selecting the provider

      config :emakola, :whatsapp_catalog_provider,
        Emakola.Notifications.Channels.WhatsappCatalog
  """

  @behaviour Emakola.Notifications.Channels.WhatsappCatalogBehaviour

  alias Emakola.Privacy

  require Logger

  @default_graph_version "v18.0"

  # ── Public API ─────────────────────────────────────────────────

  @impl true
  def upsert_product(catalog_id, payload, opts \\ []) do
    with :ok <- validate_payload(payload) do
      body = build_product_body(payload)
      url = "#{base_url()}/#{catalog_id}/products"

      Logger.info(
        "[whatsapp_catalog] upsert_product catalog=#{catalog_id} retailer_id=#{payload.retailer_id}"
      )

      post_json(url, body, opts)
    end
  end

  @impl true
  def delete_product(_catalog_id, retailer_id, opts \\ []) do
    url = "#{base_url()}/#{retailer_id}"

    Logger.info("[whatsapp_catalog] delete_product retailer_id=#{retailer_id}")

    delete(url, opts)
  end

  # ── Body Building ─────────────────────────────────────────────
  #
  # Meta Commerce expects price as a string in major units with the
  # ISO currency suffix (e.g. "12.00 GHS"). We convert from the integer
  # minor units we store internally.

  @doc """
  Builds the Meta Commerce product body from a channel payload.

  Pure function — exposed for tests and for callers that want to
  inspect the payload before sending.
  """
  def build_product_body(%{} = payload) do
    %{
      retailer_id: payload.retailer_id,
      name: payload.name,
      description: Map.get(payload, :description) || payload.name,
      price: format_price(payload.price_minor, payload.currency),
      currency: payload.currency,
      availability: format_availability(payload.availability),
      url: payload.url,
      image_url: Map.get(payload, :image_url)
    }
    |> drop_nils()
  end

  defp format_price(minor, currency) when is_integer(minor) and is_binary(currency) do
    major = div(minor, 100)
    cents = rem(abs(minor), 100)
    amount = "#{major}.#{String.pad_leading(Integer.to_string(cents), 2, "0")}"
    "#{amount} #{currency}"
  end

  defp format_availability(:in_stock), do: "in stock"
  defp format_availability(:out_of_stock), do: "out of stock"
  defp format_availability(other) when is_binary(other), do: other

  defp drop_nils(map) do
    map
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  defp validate_payload(payload) do
    required = [:retailer_id, :name, :price_minor, :currency, :availability, :url]

    missing =
      Enum.reject(required, fn key ->
        Map.has_key?(payload, key) and not is_nil(Map.get(payload, key))
      end)

    case missing do
      [] -> :ok
      keys -> {:error, {:missing_keys, keys}}
    end
  end

  # ── HTTP ──────────────────────────────────────────────────────

  defp post_json(url, body, _opts) do
    case http_client().post(url, json: body, headers: auth_headers()) do
      {:ok, %{status: status, body: resp}} when status in 200..299 ->
        {:ok, %{status: status, body: resp}}

      {:ok, %{status: status, body: resp}} ->
        Logger.error("[whatsapp_catalog] API #{status}; provider response omitted")
        {:error, %{status: status, body: resp}}

      {:error, reason} ->
        Logger.error("[whatsapp_catalog] HTTP error type=#{Privacy.error_type(reason)}")
        {:error, reason}
    end
  end

  defp delete(url, _opts) do
    case http_client().delete(url, headers: auth_headers()) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: 404}} ->
        # Already gone — treat as success so retries don't loop forever
        :ok

      {:ok, %{status: status, body: resp}} ->
        Logger.error("[whatsapp_catalog] DELETE #{status}; provider response omitted")
        {:error, %{status: status, body: resp}}

      {:error, reason} ->
        Logger.error("[whatsapp_catalog] HTTP error type=#{Privacy.error_type(reason)}")
        {:error, reason}
    end
  end

  defp auth_headers do
    [
      {"authorization", "Bearer #{api_token()}"},
      {"content-type", "application/json"}
    ]
  end

  defp base_url do
    "https://graph.facebook.com/#{graph_version()}"
  end

  defp api_token do
    config()[:api_token] || ""
  end

  defp graph_version do
    config()[:graph_version] || @default_graph_version
  end

  defp config do
    Application.get_env(:emakola, __MODULE__, [])
  end

  defp http_client do
    Application.get_env(:emakola, :http_client, Req)
  end
end
