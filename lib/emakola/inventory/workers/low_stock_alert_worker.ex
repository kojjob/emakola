defmodule Emakola.Inventory.Workers.LowStockAlertWorker do
  @moduledoc """
  Oban worker that checks inventory levels across all stores and
  alerts merchants when variant stock falls below the configured threshold.

  Runs daily via cron. For each store, queries variants with
  `track_inventory == true` and `stock_quantity < threshold`, then
  logs alerts and (optionally) sends email notifications to store merchants.

  This worker is idempotent — re-running produces the same alerts for
  the same inventory state.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  require Ash.Query
  require Logger

  @low_stock_threshold 5
  @batch_size 100

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    threshold = Map.get(args, "threshold", @low_stock_threshold)

    # Stream stores in batches so the worker memory stays bounded as
    # the platform grows. With 10k stores at one row per ~1KB, the
    # old `Ash.read!/1` would buffer ~10MB in memory and could OOM.
    stream_stores()
    |> Enum.each(&check_store_inventory(&1, threshold))

    :ok
  end

  # ── Private ─────────────────────────────────────────────────

  # Streams stores in batches via Ash.stream!/2. Each batch is read
  # into memory, processed, then GC'd before the next batch loads.
  defp stream_stores do
    Emakola.Stores.Store
    |> Ash.Query.new()
    |> Ash.stream!(authorize?: false, batch_size: @batch_size)
  end

  defp check_store_inventory(store, threshold) do
    low_stock_variants =
      Emakola.Catalog.Variant
      |> Ash.Query.filter(
        stock_quantity < ^threshold and
          track_inventory == true and
          store_id == ^store.id
      )
      |> Ash.Query.load(:product)
      |> Ash.read!(authorize?: false)

    if low_stock_variants != [] do
      Logger.warning(
        "[LowStockAlertWorker] Store #{store.name} (#{store.id}) has #{length(low_stock_variants)} low-stock variant(s)"
      )

      Enum.each(low_stock_variants, fn variant ->
        product_title = variant_product_title(variant)

        Logger.warning(
          "[LowStockAlertWorker] Low stock: #{product_title} (SKU: #{variant.sku || "N/A"}) — #{variant.stock_quantity} remaining"
        )
      end)

      send_merchant_email_alerts(store, low_stock_variants)
      send_merchant_sms_digest(store, length(low_stock_variants))
      send_merchant_whatsapp_digest(store, length(low_stock_variants))
    end
  end

  defp variant_product_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp variant_product_title(_), do: "Unknown Product"

  defp send_merchant_sms_digest(store, count) do
    message = Emakola.Notifications.Templates.low_stock_digest_sms(count, store.name)

    if store.contact_phone && store.contact_phone != "" do
      sms_provider().send_sms(store.contact_phone, message, store_id: store.id)
    end
  end

  defp sms_provider do
    Application.get_env(:emakola, :sms_provider, Emakola.Notifications.Providers.LogSMS)
  end

  # Mirrors the SMS digest on the store's WhatsApp number. Tolerates an
  # unapproved Meta template (ship-dark until "low_stock_digest" goes live)
  # the same way AnnouncementDeliveryWorker does.
  defp send_merchant_whatsapp_digest(%{whatsapp_number: number} = store, count)
       when is_binary(number) and number != "" do
    case whatsapp_provider().send_message(
           number,
           "low_stock_digest",
           %{count: count, store_name: store.name},
           store_id: store.id
         ) do
      {:ok, _} ->
        :ok

      {:error, {:unknown_template, _}} ->
        Logger.info(
          "[LowStockAlertWorker] whatsapp 'low_stock_digest' template not live; skipping store #{store.id}"
        )

        :ok

      {:error, reason} ->
        Logger.error(
          "[LowStockAlertWorker] whatsapp digest failed for store #{store.id}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp send_merchant_whatsapp_digest(_store, _count), do: :ok

  defp whatsapp_provider do
    Application.get_env(
      :emakola,
      :whatsapp_provider,
      Emakola.Notifications.Providers.LogWhatsApp
    )
  end

  defp send_merchant_email_alerts(store, low_stock_variants) do
    memberships =
      Emakola.Accounts.StoreMembership
      |> Ash.Query.filter(store_id == ^store.id)
      |> Ash.Query.load(:merchant)
      |> Ash.read!(authorize?: false)

    Enum.each(memberships, fn membership ->
      merchant = membership.merchant

      if merchant && merchant.email do
        Emakola.Inventory.Workers.LowStockAlertWorker.Email.send_alert(
          merchant,
          store,
          low_stock_variants
        )
      end
    end)
  end
end
