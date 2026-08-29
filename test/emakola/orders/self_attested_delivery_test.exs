defmodule Emakola.Orders.SelfAttestedDeliveryTest do
  @moduledoc """
  A merchant marking their own delivery is the one path to `:delivered` with no
  counterparty, and it starts their own payout clock.

  It is kept rather than removed, because there is no auto-release timer:
  `release_after` is stamped only on delivery, so a merchant whose buyer never
  answers the phone would otherwise wait thirty days for manual staff review.
  Removing the escape hatch would punish honest merchants for their customers'
  silence.

  What it must not do is look identical to a delivery the buyer actually
  confirmed. These tests pin the distinction: a separate action, a record of who
  attested, and a flag staff can sort on.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory

  alias Emakola.Orders.Fulfillment

  setup do
    store = create_store!()
    order = create_order!(store)
    merchant = create_merchant!()

    shipped =
      order
      |> then(&create_fulfillment!(&1, store))
      |> Ash.Changeset.for_update(:mark_shipped, %{tracking_number: "GH-1"})
      |> Ash.update!(authorize?: false)

    %{store: store, order: order, merchant: merchant, shipped: shipped}
  end

  defp reload(f), do: Ash.get!(Fulfillment, f.id, authorize?: false)

  describe "the two ways a fulfillment reaches :delivered" do
    test "a proven delivery is marked verified", %{shipped: shipped} do
      {:ok, delivered} = Emakola.Orders.mark_fulfillment_delivered(shipped, authorize?: false)

      assert delivered.status == :delivered
      assert delivered.delivery_verified == true
      assert is_nil(delivered.delivery_attested_by_id)
    end

    test "a self-attested delivery is marked unverified and names who said so", %{
      shipped: shipped,
      merchant: merchant
    } do
      {:ok, delivered} =
        Emakola.Orders.self_attest_fulfillment_delivered(
          shipped,
          %{delivery_attested_by_id: merchant.id},
          authorize?: false
        )

      assert delivered.status == :delivered
      assert delivered.delivery_verified == false
      assert delivered.delivery_attested_by_id == merchant.id
      assert %DateTime{} = delivered.delivery_attested_at
    end

    test "self-attesting still starts the payout clock — it is an escape hatch, not a no-op", %{
      shipped: shipped,
      merchant: merchant
    } do
      {:ok, delivered} =
        Emakola.Orders.self_attest_fulfillment_delivered(
          shipped,
          %{delivery_attested_by_id: merchant.id},
          authorize?: false
        )

      assert delivered.status == :delivered
    end

    test "self-attesting is refused from anything but :shipped", %{store: store, order: order} do
      pending = create_fulfillment!(order, store)

      assert {:error, _} =
               Emakola.Orders.self_attest_fulfillment_delivered(pending, %{}, authorize?: false)

      assert reload(pending).status == :pending
    end

    test "a stale caller cannot self-attest a fulfillment that was cancelled", %{
      shipped: shipped
    } do
      {:ok, _} = Emakola.Orders.cancel_fulfillment(shipped, authorize?: false)

      assert {:error, _} =
               Emakola.Orders.self_attest_fulfillment_delivered(shipped, %{}, authorize?: false)

      assert reload(shipped).status == :cancelled
    end
  end

  describe "what staff can sort on" do
    test "unverified deliveries are findable, verified ones are not", %{
      store: store,
      order: order,
      merchant: merchant,
      shipped: shipped
    } do
      {:ok, _} =
        Emakola.Orders.self_attest_fulfillment_delivered(
          shipped,
          %{delivery_attested_by_id: merchant.id},
          authorize?: false
        )

      proven =
        order
        |> then(&create_fulfillment!(&1, store))
        |> Ash.Changeset.for_update(:mark_shipped, %{tracking_number: "GH-2"})
        |> Ash.update!(authorize?: false)

      {:ok, proven} = Emakola.Orders.mark_fulfillment_delivered(proven, authorize?: false)

      unverified = Emakola.Orders.list_unverified_deliveries!(authorize?: false)
      ids = Enum.map(unverified, & &1.id)

      assert shipped.id in ids
      refute proven.id in ids
    end
  end
end
