defmodule Emakola.Workers.WhatsappCatalogSyncWorker do
  @moduledoc """
  Mirrors a single product to the merchant's WhatsApp Business Catalog.

  Enqueued by `Emakola.Notifications.Dispatcher` (or directly by Catalog
  context functions in Phase 2.5) on product publish/update/unpublish. The
  worker:

    1. Loads the product (with images + first variant)
    2. Loads the store and checks `whatsapp_catalog_id` is set
       — skips silently if not (merchant hasn't connected a catalog)
    3. Builds the channel payload + dispatches to the configured provider
    4. On `delete` action, calls delete_product instead

  Idempotent — Meta Commerce API treats upsert by retailer_id (we use
  the product UUID), so re-running the same job is safe.

  ## Configured queue

      :whatsapp_catalog (max_attempts 5, backoff exponential)
  """

  use Oban.Worker, queue: :whatsapp_catalog, max_attempts: 5

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    product_id = Map.fetch!(args, "product_id")
    action = Map.get(args, "action", "upsert")

    case action do
      "upsert" -> sync_upsert(product_id)
      "delete" -> sync_delete(product_id, args)
      other -> {:cancel, "unknown action: #{inspect(other)}"}
    end
  end

  defp sync_upsert(product_id) do
    require Ash.Query

    with {:ok, product} <- load_product(product_id),
         {:ok, store} <- load_store(product.store_id),
         :ok <- ensure_catalog_connected(store) do
      payload = build_payload(product, store)
      provider().upsert_product(store.whatsapp_catalog_id, payload)
    else
      :skip_no_catalog -> :ok
      {:error, _} = err -> err
    end
  end

  defp sync_delete(product_id, args) do
    # On archive (soft-delete) we still have the product row, but the
    # change module only passes us product_id + store_id — we don't need
    # to load the product because Meta Commerce keys by retailer_id (the
    # product UUID).
    case Map.fetch(args, "store_id") do
      {:ok, store_id} ->
        with {:ok, store} <- load_store(store_id),
             :ok <- ensure_catalog_connected(store) do
          provider().delete_product(store.whatsapp_catalog_id, product_id)
        else
          :skip_no_catalog -> :ok
          {:error, _} = err -> err
        end

      :error ->
        Logger.warning(
          "[whatsapp_catalog_sync] delete requested without store_id product_id=#{product_id}"
        )

        :ok
    end
  end

  defp load_product(product_id) do
    require Ash.Query

    Emakola.Catalog.Product
    |> Ash.Query.filter(id == ^product_id)
    |> Ash.Query.load([:variants, :images])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :product_not_found}
      {:ok, product} -> {:ok, product}
      {:error, _} = err -> err
    end
  end

  defp load_store(store_id) do
    require Ash.Query

    Emakola.Stores.Store
    |> Ash.Query.filter(id == ^store_id)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :store_not_found}
      {:ok, store} -> {:ok, store}
      {:error, _} = err -> err
    end
  end

  defp ensure_catalog_connected(%{whatsapp_catalog_id: nil}), do: :skip_no_catalog
  defp ensure_catalog_connected(%{whatsapp_catalog_id: ""}), do: :skip_no_catalog
  defp ensure_catalog_connected(_store), do: :ok

  defp build_payload(product, store) do
    variant = first_variant(product)
    image_url = first_image_url(product)
    storefront_host = EmakolaWeb.Endpoint.url()

    %{
      retailer_id: product.id,
      name: product.title,
      description: product.description,
      price_minor: variant_price(variant),
      currency: store.currency || "GHS",
      availability: availability(variant),
      image_url: image_url,
      url: "#{storefront_host}/@#{store.slug}/products/#{product.slug}"
    }
  end

  defp first_variant(%{variants: [v | _]}), do: v
  defp first_variant(_), do: nil

  defp first_image_url(%{images: [%{url: url} | _]}) when is_binary(url), do: url
  defp first_image_url(%{images: [%{thumbnail_url: url} | _]}) when is_binary(url), do: url
  defp first_image_url(_), do: nil

  defp variant_price(%{price: price}) when is_integer(price), do: price
  defp variant_price(_), do: 0

  defp availability(%{stock_quantity: qty}) when is_integer(qty) and qty > 0, do: :in_stock
  defp availability(_), do: :out_of_stock

  defp provider do
    Application.get_env(
      :emakola,
      :whatsapp_catalog_provider,
      Emakola.Notifications.Channels.LogWhatsappCatalog
    )
  end
end
