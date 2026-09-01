defmodule Emakola.Orders.OrderDeliveryTimestampsTest do
  use Emakola.DataCase, async: true

  alias Emakola.Factory

  setup do
    store = Factory.create_store!()
    order = Factory.create_order!(store, status: :processing)
    %{order: order}
  end

  test "mark_shipped stamps shipped_at and mark_delivered stamps delivered_at", %{order: order} do
    assert is_nil(order.shipped_at)
    assert is_nil(order.delivered_at)

    shipped =
      order
      |> Ash.Changeset.for_update(:mark_shipped, %{})
      |> Ash.update!(authorize?: false)

    assert %DateTime{} = shipped.shipped_at
    assert is_nil(shipped.delivered_at)

    delivered =
      shipped
      |> Ash.Changeset.for_update(:mark_delivered, %{})
      |> Ash.update!(authorize?: false)

    assert %DateTime{} = delivered.delivered_at
    assert DateTime.compare(delivered.delivered_at, delivered.shipped_at) in [:gt, :eq]
  end
end
