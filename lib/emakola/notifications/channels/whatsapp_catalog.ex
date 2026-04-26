defmodule Emakola.Notifications.Channels.WhatsappCatalog do
  @moduledoc """
  Meta Commerce / WhatsApp Business Catalog client.

  Phase 2 ships this as a **functional stub** that validates the payload
  shape and returns `:ok` without hitting the real API. The full Meta
  Graph integration (OAuth bearer token + retry/backoff + webhook
  reconciliation) lands in Phase 2.5 alongside the merchant OAuth
  onboarding flow.

  Why ship the stub now: the worker pipeline, payload contract, and
  Settings UI all need a stable interface to build against. Wiring the
  real HTTP calls is mechanical work that doesn't change the surrounding
  architecture; doing it once the rest of Phase 2 is validated avoids
  re-doing it if the contract evolves.

  ## Production wiring (Phase 2.5)

  When real, this will POST to:

      https://graph.facebook.com/v18.0/{catalog_id}/products

  with bearer token from `WHATSAPP_API_TOKEN` env var. Response is the
  catalog product ID. Errors retry with exponential backoff via the
  worker's max_attempts.
  """

  @behaviour Emakola.Notifications.Channels.WhatsappCatalogBehaviour

  require Logger

  @impl true
  def upsert_product(catalog_id, payload, _opts \\ []) do
    with :ok <- validate_payload(payload) do
      Logger.info(
        "[whatsapp_catalog:STUB] upsert_product catalog=#{catalog_id} retailer_id=#{payload.retailer_id} " <>
          "(real Meta Commerce API integration ships in Phase 2.5)"
      )

      {:ok, %{stubbed: true, retailer_id: payload.retailer_id, catalog_id: catalog_id}}
    end
  end

  @impl true
  def delete_product(catalog_id, retailer_id, _opts \\ []) do
    Logger.info(
      "[whatsapp_catalog:STUB] delete_product catalog=#{catalog_id} retailer_id=#{retailer_id} " <>
        "(real Meta Commerce API integration ships in Phase 2.5)"
    )

    :ok
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
end
