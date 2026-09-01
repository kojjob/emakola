defmodule Emakola.Shipping.DeliveryMetrics do
  @moduledoc """
  What a store's delivery zones actually did over a window: orders by
  status, fees collected and waived, and the orders whose region matched
  no zone at all (those paid checkout's default fee).

  Zones are matched by name, the rule `Emakola.Shipping.find_zone/2`
  applies at checkout, so a paused zone still claims the orders it took
  while it was active. Orders carry no delivery timestamps, so nothing
  here claims to know how long a delivery took.
  """

  require Ash.Query

  alias Emakola.Orders.Order
  alias Emakola.Shipping

  @to_pack [:pending, :confirmed, :processing]

  @type zone_row :: %{orders: non_neg_integer(), fees: non_neg_integer()}

  @spec for_store(binary(), [Shipping.DeliveryZone.t()], keyword()) :: map()
  def for_store(store_id, zones, opts \\ []) do
    days = Keyword.get(opts, :days, 30)
    orders = load_orders(store_id, days)
    attributed = Enum.map(orders, &{&1, Shipping.zone_for_region(zones, region_of(&1))})
    matched = for {order, zone} <- attributed, zone, do: {order, zone}
    unmatched = for {order, nil} <- attributed, do: order
    free = Enum.filter(matched, fn {order, zone} -> zone.fee > 0 and order.delivery_fee == 0 end)

    # Only orders delivered since delivered_at existed carry a time; a
    # promise needs a matched zone, so on-time is judged over those.
    timed = for {order, zone} <- attributed, timed?(order), do: {order, zone}
    promised = for {order, zone} <- timed, zone, do: {order, zone}

    %{
      total_orders: length(orders),
      delivered: count_status(orders, [:delivered]),
      on_the_way: count_status(orders, [:shipped]),
      to_pack: count_status(orders, @to_pack),
      timed: length(timed),
      promised: length(promised),
      on_time:
        Enum.count(promised, fn {order, zone} -> days_to_deliver(order) <= zone.estimated_days end),
      average_days: average_days(timed),
      fees_collected: sum_fees(orders),
      free_deliveries: length(free),
      fees_waived: free |> Enum.map(fn {_order, zone} -> zone.fee end) |> Enum.sum(),
      zones_on: Enum.count(zones, & &1.active),
      per_zone: per_zone(zones, matched),
      unmatched: %{
        orders: length(unmatched),
        fees: sum_fees(unmatched),
        regions: region_counts(unmatched)
      }
    }
  end

  defp load_orders(store_id, days) do
    since = DateTime.add(DateTime.utc_now(), -days, :day)

    Order
    |> Ash.Query.filter(store_id == ^store_id and inserted_at >= ^since and status != :cancelled)
    |> Ash.Query.set_tenant(store_id)
    |> Ash.read!(authorize?: false)
  end

  defp count_status(orders, statuses), do: Enum.count(orders, &(&1.status in statuses))

  defp timed?(%{status: :delivered, delivered_at: %DateTime{}}), do: true
  defp timed?(_order), do: false

  defp days_to_deliver(order),
    do: DateTime.diff(order.delivered_at, order.inserted_at, :second) / 86_400

  defp average_days([]), do: nil

  defp average_days(timed) do
    total = timed |> Enum.map(fn {order, _zone} -> days_to_deliver(order) end) |> Enum.sum()
    Float.round(total / length(timed), 1)
  end

  defp sum_fees(orders), do: orders |> Enum.map(&(&1.delivery_fee || 0)) |> Enum.sum()

  defp per_zone(zones, matched) do
    empty = Map.new(zones, &{&1.id, %{orders: 0, fees: 0}})

    Enum.reduce(matched, empty, fn {order, zone}, acc ->
      Map.update!(acc, zone.id, fn row ->
        %{orders: row.orders + 1, fees: row.fees + (order.delivery_fee || 0)}
      end)
    end)
  end

  # Regions are grouped as the merchant would name them, most common first.
  defp region_counts(orders) do
    orders
    |> Enum.frequencies_by(&Shipping.humanise_region(region_of(&1)))
    |> Enum.sort_by(fn {region, count} -> {-count, region} end)
  end

  defp region_of(%{shipping_address: %{"region" => region}})
       when is_binary(region) and region != "",
       do: region

  defp region_of(_order), do: nil
end
