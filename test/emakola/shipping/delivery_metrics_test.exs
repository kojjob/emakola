defmodule Emakola.Shipping.DeliveryMetricsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory
  alias Emakola.Shipping.DeliveryMetrics

  defp address(region), do: %{"region" => region, "city" => "Somewhere"}

  defp backdate!(order, days) do
    Ash.Seed.update!(order, %{inserted_at: DateTime.add(DateTime.utc_now(), -days, :day)})
  end

  test "counts deliveries, fees and unmatched regions over the last 30 days" do
    {_merchant, store} = Factory.create_merchant_with_store!()

    accra =
      Factory.create_delivery_zone!(store,
        name: "Greater Accra",
        fee: 1500,
        free_above_pesewas: 20_000
      )

    ashanti =
      Factory.create_delivery_zone!(store, name: "Kumasi/Ashanti", fee: 2500, active: false)

    for region <- ["greater_accra", "Greater Accra"] do
      Factory.create_order!(store,
        shipping_address: address(region),
        delivery_fee: 1500,
        status: :delivered
      )
    end

    # Free above the threshold: the zone charges, this order paid nothing.
    Factory.create_order!(store,
      shipping_address: address("greater_accra"),
      delivery_fee: 0,
      status: :delivered
    )

    Factory.create_order!(store,
      shipping_address: address("Kumasi/Ashanti"),
      delivery_fee: 2500,
      status: :shipped
    )

    Factory.create_order!(store,
      shipping_address: address("Volta"),
      delivery_fee: 3500,
      status: :pending
    )

    # Cancelled and out-of-window orders never count.
    Factory.create_order!(store,
      shipping_address: address("greater_accra"),
      delivery_fee: 1500,
      status: :cancelled
    )

    store
    |> Factory.create_order!(
      shipping_address: address("greater_accra"),
      delivery_fee: 1500,
      status: :delivered
    )
    |> backdate!(40)

    metrics = DeliveryMetrics.for_store(store.id, [accra, ashanti])

    assert metrics.total_orders == 5
    assert metrics.delivered == 3
    assert metrics.on_the_way == 1
    assert metrics.to_pack == 1
    assert metrics.fees_collected == 1500 + 1500 + 2500 + 3500
    assert metrics.free_deliveries == 1
    assert metrics.fees_waived == 1500
    assert metrics.zones_on == 1
    assert metrics.per_zone[accra.id] == %{orders: 3, fees: 3000}
    assert metrics.per_zone[ashanti.id] == %{orders: 1, fees: 2500}
    assert metrics.unmatched == %{orders: 1, fees: 3500, regions: [{"Volta", 1}]}
  end

  test "on-time rate and average days come from delivered_at against the zone's promise" do
    {_merchant, store} = Factory.create_merchant_with_store!()

    accra =
      Factory.create_delivery_zone!(store, name: "Greater Accra", fee: 1500, estimated_days: 1)

    # Placed 3 days ago, delivered 1 day later: on time for a 1-day promise.
    on_time =
      store
      |> Factory.create_order!(shipping_address: address("greater_accra"), status: :delivered)
      |> backdate!(3)

    Ash.Seed.update!(on_time, %{delivered_at: DateTime.add(on_time.inserted_at, 1, :day)})

    # Placed 5 days ago, delivered 4 days later: late.
    late =
      store
      |> Factory.create_order!(shipping_address: address("greater_accra"), status: :delivered)
      |> backdate!(5)

    Ash.Seed.update!(late, %{delivered_at: DateTime.add(late.inserted_at, 4, :day)})

    # Delivered before timestamps existed: counted as delivered, not timed.
    Factory.create_order!(store, shipping_address: address("greater_accra"), status: :delivered)

    metrics = DeliveryMetrics.for_store(store.id, [accra])

    assert metrics.delivered == 3
    assert metrics.timed == 2
    assert metrics.on_time == 1
    assert metrics.average_days == 2.5
  end

  test "with no timed deliveries the rate and average are nil" do
    {_merchant, store} = Factory.create_merchant_with_store!()
    Factory.create_order!(store, shipping_address: address("Volta"), status: :delivered)

    metrics = DeliveryMetrics.for_store(store.id, [])

    assert metrics.timed == 0
    assert metrics.on_time == 0
    assert metrics.average_days == nil
  end

  test "a store with no orders reports zeros" do
    {_merchant, store} = Factory.create_merchant_with_store!()
    zone = Factory.create_delivery_zone!(store, name: "Greater Accra", fee: 1500)

    metrics = DeliveryMetrics.for_store(store.id, [zone])

    assert metrics.total_orders == 0
    assert metrics.fees_collected == 0
    assert metrics.per_zone[zone.id] == %{orders: 0, fees: 0}
    assert metrics.unmatched == %{orders: 0, fees: 0, regions: []}
  end

  test "a region no zone names goes to the catch-all zone, not to unmatched" do
    {_merchant, store} = Factory.create_merchant_with_store!()
    accra = Factory.create_delivery_zone!(store, name: "Greater Accra", fee: 1500)
    rest = Factory.create_delivery_zone!(store, name: "Other Regions", fee: 3500, fallback: true)

    Factory.create_order!(store, shipping_address: address("Volta"), delivery_fee: 3500)
    Factory.create_order!(store, shipping_address: address("greater_accra"), delivery_fee: 1500)

    metrics = DeliveryMetrics.for_store(store.id, [accra, rest])

    assert metrics.per_zone[rest.id] == %{orders: 1, fees: 3500}
    assert metrics.per_zone[accra.id] == %{orders: 1, fees: 1500}
    assert metrics.unmatched.orders == 0
  end

  test "orders without a region count as unmatched under Not given" do
    {_merchant, store} = Factory.create_merchant_with_store!()

    Factory.create_order!(store, delivery_fee: 3500, status: :confirmed)

    metrics = DeliveryMetrics.for_store(store.id, [])

    assert metrics.to_pack == 1
    assert metrics.unmatched == %{orders: 1, fees: 3500, regions: [{"Not given", 1}]}
  end
end
