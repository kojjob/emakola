defmodule Emakola.Notifications.Channels.WhatsappCatalogBehaviour do
  @moduledoc """
  Provider contract for the WhatsApp Business Catalog mirror.

  Implementations:

    * `Emakola.Notifications.Channels.WhatsappCatalog` — Meta Commerce API
      client (Phase 2 ships a stub that logs + returns `:ok`; full Meta
      Graph integration follows in Phase 2.5)
    * `Emakola.Notifications.Channels.LogWhatsappCatalog` — dev/test
      stub that logs and returns `:ok`

  Configured via:

      config :emakola, :whatsapp_catalog_provider,
        Emakola.Notifications.Channels.WhatsappCatalog
  """

  @typedoc """
  The product fields the worker hands to the channel. Currency string is
  ISO 4217. Price is in minor units (pesewas/kobo).
  """
  @type product_payload :: %{
          required(:retailer_id) => String.t(),
          required(:name) => String.t(),
          required(:description) => String.t() | nil,
          required(:price_minor) => non_neg_integer(),
          required(:currency) => String.t(),
          required(:availability) => :in_stock | :out_of_stock,
          required(:image_url) => String.t() | nil,
          required(:url) => String.t()
        }

  @callback upsert_product(
              catalog_id :: String.t(),
              payload :: product_payload(),
              opts :: keyword()
            ) ::
              {:ok, map()} | {:error, term()}

  @callback delete_product(catalog_id :: String.t(), retailer_id :: String.t(), opts :: keyword()) ::
              :ok | {:error, term()}
end
