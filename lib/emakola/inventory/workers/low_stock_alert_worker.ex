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

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    threshold = Map.get(args, "threshold", @low_stock_threshold)

    stores = list_active_stores()

    Enum.each(stores, fn store ->
      check_store_inventory(store, threshold)
    end)

    :ok
  end

  # ── Private ─────────────────────────────────────────────────

  defp list_active_stores do
    Emakola.Stores.Store
    |> Ash.read!(authorize?: false)
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
