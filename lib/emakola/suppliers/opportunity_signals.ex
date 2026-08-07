defmodule Emakola.Suppliers.OpportunitySignals do
  @moduledoc "Records and reads privacy-safe demand signals without customer identifiers or raw searches."

  require Ash.Query

  @event_names ["earn.product_view", "earn.catalog_search"]
  @max_products 10

  def track_product_view(store_id, product_id) do
    track("earn.product_view", %{"store_id" => store_id, "product_id" => product_id})
  end

  def track_search(store_id, query, products) do
    normalized = normalize(query)

    if normalized == "" do
      :ok
    else
      metadata = %{
        "store_id" => store_id,
        "query_fingerprint" => fingerprint(normalized),
        "query_length_bucket" => length_bucket(String.length(normalized)),
        "result_count" => length(products),
        "matched_product_ids" => products |> Enum.take(@max_products) |> Enum.map(& &1.id)
      }

      track("earn.catalog_search", metadata)
    end
  end

  def recent(days \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    Emakola.Analytics.AppEvent
    |> Ash.Query.filter(event_name in ^@event_names and occurred_at >= ^since)
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.read(authorize?: false)
  end

  def emit_supplier_alerts(radar) do
    Enum.each(radar, fn item ->
      if item.supplier_alert? and not alert_exists?(item.offer_id) do
        track("earn.supplier_demand_alert", %{
          "offer_id" => item.offer_id,
          "wholesaler_store_id" => item.wholesaler_store_id,
          "title" => String.slice(item.title, 0, 120),
          "views" => item.views,
          "matched_searches" => item.searches,
          "orders" => item.orders,
          "window_days" => 30
        })
      end
    end)

    :ok
  end

  def supplier_alerts(store_id, days \\ 30) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    Emakola.Analytics.AppEvent
    |> Ash.Query.filter(
      event_name == "earn.supplier_demand_alert" and occurred_at >= ^since and
        fragment("? ->> 'wholesaler_store_id' = ?", metadata, ^store_id)
    )
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.read(authorize?: false)
  end

  def fingerprint(query) do
    key =
      :emakola
      |> Application.get_env(EmakolaWeb.Endpoint, [])
      |> Keyword.get(:secret_key_base, "emakola-opportunity-signals-local")

    :crypto.mac(:hmac, :sha256, key, query)
    |> Base.encode16(case: :lower)
  end

  defp alert_exists?(offer_id) do
    since = DateTime.add(DateTime.utc_now(), -1, :day)

    Emakola.Analytics.AppEvent
    |> Ash.Query.filter(
      event_name == "earn.supplier_demand_alert" and occurred_at >= ^since and
        fragment("? ->> 'offer_id' = ?", metadata, ^offer_id)
    )
    |> Ash.exists?(authorize?: false)
  end

  defp track(name, metadata) do
    case Emakola.Analytics.track(name, metadata: metadata) do
      {:ok, _event} -> :ok
      _error -> :ok
    end
  rescue
    _exception -> :ok
  end

  defp normalize(query),
    do: query |> to_string() |> String.trim() |> String.downcase() |> String.slice(0, 80)

  defp length_bucket(length) when length <= 5, do: "1-5"
  defp length_bucket(length) when length <= 15, do: "6-15"
  defp length_bucket(length) when length <= 30, do: "16-30"
  defp length_bucket(_length), do: "31-80"
end
