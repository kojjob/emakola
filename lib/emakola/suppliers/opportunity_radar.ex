defmodule Emakola.Suppliers.OpportunityRadar do
  @moduledoc "Aggregates privacy-safe demand, sales, fulfillment, refund, stock, and regional signals."

  alias Emakola.Suppliers.{EthicalPricing, SalesSharing}

  @region_threshold 3

  def build(offers, listings, shares, events, store_id) do
    listings_by_offer = Map.new(listings, &{&1.offer_id, &1})
    shares_by_product = Enum.group_by(shares, & &1.product_id)

    offers
    |> Enum.map(fn offer ->
      listing = Map.get(listings_by_offer, offer.id)
      product_id = listing && listing.reseller_product_id
      product_shares = Map.get(shares_by_product, product_id, [])
      conversions = Enum.flat_map(product_shares, & &1.conversions)
      views = count_events(events, "earn.product_view", product_id, store_id)
      searches = count_searches(events, product_id, store_id)
      fulfilled = Enum.count(conversions, &SalesSharing.delivered_conversion?/1)
      refunded = Enum.count(conversions, &refunded?/1)
      stock = Enum.sum(Enum.map(offer.offer_variants, &(&1.source_variant.stock_quantity || 0)))
      variant = Enum.max_by(offer.offer_variants, &margin/1)
      pricing = EthicalPricing.recommend(variant, %{views: views, orders: length(conversions)})
      latest = latest_signal(events, product_id, store_id)

      %{
        id: offer.id,
        offer_id: offer.id,
        wholesaler_store_id: Map.get(offer, :wholesaler_store_id),
        product_id: product_id,
        title: offer.source_product.title,
        views: views,
        searches: searches,
        shares: Enum.sum(Enum.map(product_shares, & &1.share_count)),
        orders: length(conversions),
        fulfilled: fulfilled,
        refunded: refunded,
        stock: stock,
        regions: safe_regions(conversions),
        pricing: pricing,
        freshness: freshness(latest),
        confidence: confidence(views + searches + length(conversions)),
        supplier_alert?: views + searches >= 20 and conversions == [],
        explanation: explanation(views, searches, conversions, fulfilled, refunded, stock)
      }
    end)
    |> Enum.sort_by(&{-(&1.views + &1.searches), -&1.fulfilled, &1.refunded, &1.title})
  end

  defp count_events(events, name, product_id, store_id) do
    Enum.count(events, &(event?(&1, name, store_id) and &1.metadata["product_id"] == product_id))
  end

  defp count_searches(events, product_id, store_id) do
    Enum.count(events, fn event ->
      event?(event, "earn.catalog_search", store_id) and
        product_id in Map.get(event.metadata, "matched_product_ids", [])
    end)
  end

  defp latest_signal(events, product_id, store_id) do
    events
    |> Enum.filter(fn event ->
      event.metadata["store_id"] == store_id and
        (event.metadata["product_id"] == product_id or
           product_id in Map.get(event.metadata, "matched_product_ids", []))
    end)
    |> Enum.map(& &1.occurred_at)
    |> Enum.max_by(&DateTime.to_unix(&1, :microsecond), fn -> nil end)
  end

  defp event?(event, name, store_id),
    do: event.event_name == name and event.metadata["store_id"] == store_id

  defp margin(variant), do: variant.suggested_retail_price - variant.supplier_price

  defp refunded?(conversion) do
    case Emakola.Payments.get_payment_by_order(conversion.order_id, authorize?: false) do
      {:ok, payment} -> payment.refunded_amount > 0
      _error -> false
    end
  end

  defp safe_regions(conversions) do
    conversions
    |> Enum.map(&city/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_city, count} -> count >= @region_threshold end)
    |> Enum.sort_by(fn {city, count} -> {-count, city} end)
  end

  defp city(%{order: %{shipping_address: address}}) when is_map(address),
    do: Map.get(address, "city") || Map.get(address, :city)

  defp city(_conversion), do: nil

  defp freshness(nil), do: %{label: "No demand signal yet", observed_at: nil}

  defp freshness(datetime),
    do: %{
      label: "Updated #{Calendar.strftime(datetime, "%d %b %Y %H:%M UTC")}",
      observed_at: datetime
    }

  defp confidence(total) when total >= 50, do: :high
  defp confidence(total) when total >= 10, do: :medium
  defp confidence(total) when total >= 1, do: :early
  defp confidence(_total), do: :new

  defp explanation(views, searches, conversions, fulfilled, refunded, stock) do
    "#{Emakola.Plural.count(views, "view")}, #{Emakola.Plural.count(searches, "matched search")}, #{Emakola.Plural.count(length(conversions), "order")}, #{fulfilled} fulfilled, #{refunded} refunded, and #{Emakola.Plural.count(stock, "unit")} available."
  end
end
