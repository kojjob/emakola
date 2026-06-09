defmodule Emakola.Orders.OrderFulfillmentStatusTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  setup do
    store = create_store!()
    order = create_order!(store)
    {:ok, store: store, order: order}
  end

  defp fulfillment_status(order) do
    order
    |> Ash.load!(:fulfillment_status, authorize?: false)
    |> Map.get(:fulfillment_status)
  end

  defp ship_and_deliver(fulfillment) do
    fulfillment
    |> Ash.Changeset.for_update(:mark_shipped, %{})
    |> Ash.update!(authorize?: false)
    |> Ash.Changeset.for_update(:mark_delivered, %{})
    |> Ash.update!(authorize?: false)
  end

  test "no fulfillments → nil", %{order: order} do
    assert is_nil(fulfillment_status(order))
  end

  test "all delivered → :delivered", %{store: store, order: order} do
    create_fulfillment!(order, store) |> ship_and_deliver()
    create_fulfillment!(order, store) |> ship_and_deliver()

    assert fulfillment_status(order) == :delivered
  end

  test "mixed shipped + pending → :pending (least progressed)", %{store: store, order: order} do
    create_fulfillment!(order, store)
    |> Ash.Changeset.for_update(:mark_shipped, %{})
    |> Ash.update!(authorize?: false)

    create_fulfillment!(order, store)

    assert fulfillment_status(order) == :pending
  end

  test "all cancelled → :cancelled", %{store: store, order: order} do
    for _ <- 1..2 do
      create_fulfillment!(order, store)
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)
    end

    assert fulfillment_status(order) == :cancelled
  end

  test "ignores cancelled when computing least-progressed", %{store: store, order: order} do
    # One cancelled, one shipped → :shipped (cancelled ignored)
    create_fulfillment!(order, store)
    |> Ash.Changeset.for_update(:cancel, %{})
    |> Ash.update!(authorize?: false)

    create_fulfillment!(order, store)
    |> Ash.Changeset.for_update(:mark_shipped, %{})
    |> Ash.update!(authorize?: false)

    assert fulfillment_status(order) == :shipped
  end
end
