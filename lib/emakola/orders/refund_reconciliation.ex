defmodule Emakola.Orders.RefundReconciliation do
  @moduledoc """
  Reconciles a fully refunded payment with its order and fulfillments.

  Unfulfilled orders are cancelled together with every still-pending
  fulfillment, and stock decremented for the order is restored. Once either
  the order or any fulfillment has shipped/delivered, its history is
  preserved: financial state records the refund, while operational state
  continues to describe what physically happened.

  The caller (`Emakola.Payments.RefundReconciliation`) already holds the
  payment lock and transaction. This module locks the order and its
  fulfillments before deciding, making concurrent refund deliveries serialize
  on the same rows and keeping payment/order changes all-or-nothing.
  """

  import Ecto.Query, only: [from: 2]

  require Ash.Query

  alias Emakola.Orders.{Fulfillment, Order}
  alias Emakola.Payments.Payment
  alias Emakola.Repo

  @active_order_statuses [:pending, :confirmed, :processing]
  @active_fulfillment_statuses [:pending, :notified]
  @dispatched_statuses [:shipped, :delivered]

  @doc "Reconciles the order attached to a fully refunded payment."
  @spec reconcile(%Payment{}) ::
          :no_order | :order_not_found | :already_cancelled | :cancelled | :history_preserved
  def reconcile(%Payment{status: :refunded, order_id: nil}), do: :no_order

  def reconcile(%Payment{status: :refunded, order_id: order_id, store_id: store_id}) do
    case Repo.one(locked_order_query(order_id, store_id)) do
      nil ->
        :order_not_found

      _order_id ->
        order = Ash.get!(Order, order_id, authorize?: false)
        fulfillments = locked_fulfillments(order_id, store_id)

        cond do
          dispatched?(order, fulfillments) ->
            :history_preserved

          order.status == :cancelled ->
            cancel_pending_fulfillments(fulfillments)
            restore_stock(order.id)
            :already_cancelled

          order.status in @active_order_statuses ->
            cancel_pending_fulfillments(fulfillments)

            order
            |> Ash.Changeset.for_update(:cancel, %{})
            |> Ash.update!(authorize?: false)

            restore_stock(order.id)
            :cancelled

          true ->
            :history_preserved
        end
    end
  end

  def reconcile(_payment), do: :no_order

  @doc false
  def locked_order_query(order_id, store_id) do
    from(o in "orders",
      where: o.id == type(^order_id, :binary_id) and o.store_id == type(^store_id, :binary_id),
      lock: "FOR UPDATE",
      select: type(o.id, :binary_id)
    )
  end

  defp locked_fulfillments(order_id, store_id) do
    Fulfillment
    |> Ash.Query.filter(order_id == ^order_id and store_id == ^store_id)
    |> Ash.Query.sort(id: :asc)
    |> Ash.Query.lock("FOR UPDATE")
    |> Ash.read!(authorize?: false)
  end

  defp dispatched?(order, fulfillments) do
    order.status in @dispatched_statuses or
      Enum.any?(fulfillments, &(&1.status in @dispatched_statuses))
  end

  defp cancel_pending_fulfillments(fulfillments) do
    fulfillments
    |> Enum.filter(&(&1.status in @active_fulfillment_statuses))
    |> Enum.each(fn fulfillment ->
      fulfillment
      |> Ash.Changeset.for_update(:cancel, %{})
      |> Ash.update!(authorize?: false)
    end)
  end

  defp restore_stock(order_id) do
    with {:ok, _restored_sales} <- Emakola.Inventory.restore_refunded_order(order_id),
         {:ok, _restored_reservations} <-
           Emakola.Suppliers.InventoryReservations.restore_for_refunded_order(order_id) do
      :ok
    else
      {:error, reason} -> Repo.rollback({:stock_restore_failed, reason})
    end
  end
end
