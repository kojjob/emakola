defmodule Emakola.Notifications.Channels.LogWhatsappCatalog do
  @moduledoc """
  Stub provider for the WhatsApp Business Catalog mirror. Logs only
  non-content identifiers and returns success. Used in dev/test where we
  don't want to hit the Meta Commerce API.

  Configure via:

      config :emakola, :whatsapp_catalog_provider,
        Emakola.Notifications.Channels.LogWhatsappCatalog
  """

  @behaviour Emakola.Notifications.Channels.WhatsappCatalogBehaviour

  require Logger

  @impl true
  def upsert_product(catalog_id, payload, _opts \\ []) do
    Logger.info(
      "[whatsapp_catalog:LOG] upsert_product catalog=#{catalog_id} retailer_id=#{payload.retailer_id}",
      catalog_id: catalog_id,
      retailer_id: payload.retailer_id
    )

    {:ok, %{logged: true, retailer_id: payload.retailer_id}}
  end

  @impl true
  def delete_product(catalog_id, retailer_id, _opts \\ []) do
    Logger.info(
      "[whatsapp_catalog:LOG] delete_product catalog=#{catalog_id} retailer_id=#{retailer_id}",
      catalog_id: catalog_id,
      retailer_id: retailer_id
    )

    :ok
  end
end
