defmodule Emakola.Inventory.Workers.LowStockSmsWorker do
  @moduledoc """
  Oban worker that sends real-time SMS and WhatsApp alerts to merchants
  when a variant's stock drops below the threshold.

  Enqueued by CheckoutService after stock decrement. Idempotent: checks
  that `low_stock_alerted` is still true before sending (variant may have
  been restocked between enqueue and execution).
  """

  use Oban.Worker,
    queue: :notifications,
    max_attempts: 3

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Templates

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"variant_id" => variant_id, "store_id" => store_id}}) do
    with {:ok, variant} <- load_variant(variant_id),
         true <- variant.low_stock_alerted,
         {:ok, store} <- load_store(store_id) do
      product_title = variant_product_title(variant)

      message =
        Templates.low_stock_realtime_sms(
          product_title,
          variant.sku,
          variant.stock_quantity,
          store.name
        )

      send_merchant_sms(store, message)

      Logger.info(
        "[LowStockSmsWorker] Alert sent for #{product_title} (#{variant.stock_quantity} remaining) — store #{store.name}"
      )
    else
      false ->
        Logger.info("[LowStockSmsWorker] Skipped — variant was restocked")

      {:error, :not_found} ->
        Logger.warning("[LowStockSmsWorker] Variant or store not found, skipping")
    end

    :ok
  end

  defp load_variant(variant_id) do
    case Emakola.Catalog.Variant
         |> Ash.Query.filter(id == ^variant_id)
         |> Ash.Query.load(:product)
         |> Ash.read!(authorize?: false) do
      [variant] -> {:ok, variant}
      [] -> {:error, :not_found}
    end
  end

  defp load_store(store_id) do
    case Ash.get(Emakola.Accounts.Store, store_id, authorize?: false) do
      {:ok, store} -> {:ok, store}
      _ -> {:error, :not_found}
    end
  end

  defp variant_product_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp variant_product_title(_), do: "Unknown Product"

  defp send_merchant_sms(store, message) do
    if store.contact_phone && store.contact_phone != "" do
      sms_provider().send_sms(store.contact_phone, message, store_id: store.id)
    end
  end

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end
end
