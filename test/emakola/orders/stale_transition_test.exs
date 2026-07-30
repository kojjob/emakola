defmodule Emakola.Orders.StaleTransitionTest do
  @moduledoc """
  A caller holding a stale order must not be able to drive an illegal status
  transition.

  `StatusGuard` reads the status off the changeset — i.e. the record the caller
  loaded. A merchant with the order open in a second tab holds a struct saying
  `:pending` long after the row moved on, so the validation passes and the
  write lands. The worst case is a CANCELLED order flipped back to
  `:confirmed`: the customer gets an order-confirmed notification and
  fulfilment is enqueued for an order they were told was cancelled.

  `RequireStatusIn` pushes the same predicate into the UPDATE's WHERE clause so
  the database decides.
  """
  use Emakola.DataCase, async: true

  alias Emakola.Orders.Order

  setup do
    store = Emakola.Factory.create_store!()
    order = Emakola.Factory.create_order!(store, %{status: :pending})
    %{store: store, order: order}
  end

  defp reload(order), do: Ash.get!(Order, order.id, authorize?: false)

  test "a stale :pending struct cannot confirm an order that was cancelled", %{order: order} do
    # `order` is the stale handle the second tab is holding.
    {:ok, cancelled} = Emakola.Orders.cancel_order(order, authorize?: false)
    assert cancelled.status == :cancelled

    assert {:error, error} = Emakola.Orders.confirm_order(order, authorize?: false)

    # Whatever the error shape, the crucial part is that the row did NOT move.
    assert reload(order).status == :cancelled,
           "a cancelled order was resurrected by a stale confirm: #{inspect(error)}"
  end

  test "a stale struct cannot confirm an already-confirmed order twice", %{order: order} do
    {:ok, _} = Emakola.Orders.confirm_order(order, authorize?: false)

    # Second confirm from the stale handle must be rejected, not silently
    # re-applied (it would re-fire the confirmation notification).
    assert {:error, _} = Emakola.Orders.confirm_order(order, authorize?: false)
    assert reload(order).status == :confirmed
  end

  test "a stale struct cannot cancel an order that was already delivered", %{order: order} do
    {:ok, confirmed} = Emakola.Orders.confirm_order(order, authorize?: false)
    {:ok, processing} = Emakola.Orders.start_processing_order(confirmed, authorize?: false)
    {:ok, shipped} = Emakola.Orders.mark_order_shipped(processing, %{}, authorize?: false)
    {:ok, delivered} = Emakola.Orders.mark_order_delivered(shipped, authorize?: false)
    assert delivered.status == :delivered

    # `order` still says :pending, which cancel's from-list allows.
    assert {:error, _} = Emakola.Orders.cancel_order(order, authorize?: false)
    assert reload(order).status == :delivered
  end

  test "the happy path still works from a fresh record", %{order: order} do
    assert {:ok, confirmed} = Emakola.Orders.confirm_order(order, authorize?: false)
    assert confirmed.status == :confirmed

    assert {:ok, processing} =
             Emakola.Orders.start_processing_order(confirmed, authorize?: false)

    assert processing.status == :processing
  end
end
