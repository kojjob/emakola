defmodule Emakola.Payments.UnverifiedDeliveryQueueTest do
  @moduledoc """
  Staff need to be able to find a delivery that only the merchant vouched for.

  The protection queue's existing two worklists cannot: a self-attested delivery
  raises no complaint, so it is not frozen, and it DOES start the release timer,
  so it is not stale. It looks exactly like a clean delivery until somebody
  compares the two fields, which nobody was going to do by hand.
  """
  use Emakola.DataCase, async: false

  import Emakola.Factory

  alias Emakola.Payments.ProtectionHolds

  defp held_order_with_delivery(verified?) do
    store = create_store!()
    order = create_order!(store)
    merchant = create_merchant!()

    payment =
      create_payment!(store, %{
        order_id: order.id,
        payout_hold_reason: "buyer_protection"
      })

    :ok = ProtectionHolds.ensure_hold(payment)

    fulfillment =
      order
      |> then(&create_fulfillment!(&1, store))
      |> Ash.Changeset.for_update(:mark_shipped, %{tracking_number: "GH-Q1"})
      |> Ash.update!(authorize?: false)

    if verified? do
      {:ok, _} = Emakola.Orders.mark_fulfillment_delivered(fulfillment, authorize?: false)
    else
      {:ok, _} =
        Emakola.Orders.self_attest_fulfillment_delivered(
          fulfillment,
          %{delivery_attested_by_id: merchant.id},
          authorize?: false
        )
    end

    %{store: store, order: order}
  end

  test "lists a hold whose delivery was only self-attested" do
    %{order: order} = held_order_with_delivery(false)

    order_ids = ProtectionHolds.list_unverified_delivery() |> Enum.map(& &1.order_id)

    assert order.id in order_ids
  end

  test "does not list a hold whose buyer confirmed with their code" do
    %{order: order} = held_order_with_delivery(true)

    order_ids = ProtectionHolds.list_unverified_delivery() |> Enum.map(& &1.order_id)

    refute order.id in order_ids
  end
end
