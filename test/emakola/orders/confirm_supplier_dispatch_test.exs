defmodule Emakola.Orders.ConfirmSupplierDispatchTest do
  @moduledoc """
  Integration test for the supplier-notification auto-trigger on order
  confirmation. Confirming an order must enqueue a SupplierNotificationWorker
  for each pending supplier fulfillment, and none for a merchant-only order.
  """
  use Emakola.DataCase, async: false
  use Oban.Testing, repo: Emakola.Repo

  alias Emakola.Factory
  alias Emakola.Notifications.Workers.SupplierNotificationWorker

  test "confirming an order with a supplier fulfillment enqueues a supplier job" do
    {_merchant, store} = Factory.create_merchant_with_store!()
    order = Factory.create_order!(store, %{total: 10_000, currency: "GHS"})
    supplier = Factory.create_supplier!(store, %{whatsapp_number: "+233200000001"})
    fulfillment = Factory.create_fulfillment!(order, store, %{supplier_id: supplier.id})

    {:ok, _confirmed} = Ash.update(order, %{}, action: :confirm, authorize?: false)

    assert_enqueued(
      worker: SupplierNotificationWorker,
      args: %{fulfillment_id: fulfillment.id},
      queue: :notifications
    )
  end

  test "confirming an order with only a merchant group enqueues no supplier job" do
    {_merchant, store} = Factory.create_merchant_with_store!()
    order = Factory.create_order!(store, %{total: 10_000, currency: "GHS"})
    _merchant_group = Factory.create_fulfillment!(order, store, %{supplier_id: nil})

    {:ok, _confirmed} = Ash.update(order, %{}, action: :confirm, authorize?: false)

    refute_enqueued(worker: SupplierNotificationWorker)
  end
end
