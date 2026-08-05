defmodule Emakola.Orders.DigitalFulfillmentTest do
  @moduledoc """
  A digital order's Fulfillment row sat `:pending` forever — `:shipped`
  requires a tracking number and `:delivered` requires coming from `:shipped`,
  neither of which a download can supply. Two consequences: the admin shows a
  perpetual "pending shipment" for a file, and — far worse — at a
  buyer-protection store the payout hold never releases, because
  `StampProtectionReleaseAfter` hangs off delivery. The merchant would silently
  never be paid.

  The row is kept rather than skipped: Fulfillment is the order↔supplier
  grouping that `OrderSettlement.load_line_items/2` reads to find each line's
  supplier, and `SupplierLedgerEntry.fulfillment_id` is `allow_nil?: false`.
  """
  use Emakola.DataCase, async: true

  import Emakola.Factory
  require Ash.Query

  alias Emakola.Orders.Fulfillment
  alias Emakola.Workers.FulfillmentWorker

  defp digital_store! do
    create_store!()
    |> Ash.Changeset.for_update(:update_settings, %{
      enabled_product_types: [:physical, :digital_download]
    })
    |> Ash.update!(authorize?: false)
  end

  defp fulfillment_for(order) do
    Fulfillment
    |> Ash.Query.filter(order_id == ^order.id)
    |> Ash.read!(authorize?: false)
    |> List.first()
  end

  defp checkout!(store, items) do
    {:ok, order} = Emakola.Orders.CheckoutService.checkout!(store.id, items, [])
    order
  end

  describe "Fulfillment :mark_delivered_digitally" do
    test "moves pending straight to delivered" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store, price: 5000, sku: "DFT-A")
      order = checkout!(store, [%{variant_id: variant.id, quantity: 1}])

      fulfillment = fulfillment_for(order)
      assert fulfillment.status == :pending

      updated =
        fulfillment
        |> Ash.Changeset.for_update(:mark_delivered_digitally, %{})
        |> Ash.update!(authorize?: false)

      assert updated.status == :delivered
    end

    # Oban retries up to 5 times; the guard makes a second run a no-op rather
    # than a crash, exactly as Order :confirm's from: [:pending] guard does.
    test "is refused from any state other than pending" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store, price: 5000, sku: "DFT-B")
      order = checkout!(store, [%{variant_id: variant.id, quantity: 1}])

      delivered =
        fulfillment_for(order)
        |> Ash.Changeset.for_update(:mark_delivered_digitally, %{})
        |> Ash.update!(authorize?: false)

      assert {:error, _} =
               delivered
               |> Ash.Changeset.for_update(:mark_delivered_digitally, %{})
               |> Ash.update(authorize?: false)
    end

    # Regression: the existing physical guard must not be relaxed.
    test "mark_delivered still refuses pending" do
      store = create_store!()
      product = create_product!(store)
      variant = create_variant!(product, store, price: 5000, sku: "DFT-C", stock_quantity: 5)
      order = checkout!(store, [%{variant_id: variant.id, quantity: 1}])

      assert {:error, _} =
               fulfillment_for(order)
               |> Ash.Changeset.for_update(:mark_delivered, %{})
               |> Ash.update(authorize?: false)
    end
  end

  describe "FulfillmentWorker" do
    test "marks an all-digital group delivered" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store, price: 5000, sku: "DFT-D")
      order = checkout!(store, [%{variant_id: variant.id, quantity: 1}])

      assert :ok = FulfillmentWorker.perform(%Oban.Job{args: %{"order_id" => order.id}})

      assert fulfillment_for(order).status == :delivered
    end

    test "leaves a mixed group pending — the merchant still has to ship it" do
      store = digital_store!()
      digital_product = create_product!(store, product_type: :digital_download)
      digital = create_variant!(digital_product, store, price: 5000, sku: "DFT-E")

      physical_product = create_product!(store)

      physical =
        create_variant!(physical_product, store, price: 5000, sku: "DFT-F", stock_quantity: 5)

      order =
        checkout!(store, [
          %{variant_id: digital.id, quantity: 1},
          %{variant_id: physical.id, quantity: 1}
        ])

      assert :ok = FulfillmentWorker.perform(%Oban.Job{args: %{"order_id" => order.id}})

      assert fulfillment_for(order).status == :pending
    end

    # The existing tests in fulfillment_worker_test.exs build line items with
    # no fulfillment_id at all, so the grouping must skip nils rather than
    # crash.
    test "tolerates line items with no fulfillment" do
      store = digital_store!()
      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store, price: 5000, sku: "DFT-G")
      customer = create_customer!(store)
      order = create_order!(store, customer_id: customer.id)

      Emakola.Orders.LineItem
      |> Ash.Changeset.for_create(:create, %{
        order_id: order.id,
        store_id: store.id,
        variant_id: variant.id,
        quantity: 1
      })
      |> Ash.create!(authorize?: false)

      assert :ok = FulfillmentWorker.perform(%Oban.Job{args: %{"order_id" => order.id}})
    end
  end

  # The reason this step matters most. StampProtectionReleaseAfter hangs off
  # delivery, so before this change a protected digital order's held payment
  # had no path to release at all — ProtectionSweepWorker would never pay the
  # merchant, silently and forever.
  describe "buyer protection" do
    test "auto-delivery stamps the payout hold's release timer" do
      store =
        digital_store!()
        |> Ash.Changeset.for_update(:update_settings, %{buyer_protection_enabled: true})
        |> Ash.update!(authorize?: false)

      product = create_product!(store, product_type: :digital_download)
      variant = create_variant!(product, store, price: 5000, sku: "DFT-P")
      order = checkout!(store, [%{variant_id: variant.id, quantity: 1}])

      payment =
        Emakola.Payments.Payment
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          order_id: order.id,
          amount: 5000,
          currency: "GHS",
          gateway: :paystack,
          gateway_reference: "PAY-DFT-#{System.unique_integer([:positive])}",
          payout_held: true,
          payout_hold_reason: "buyer_protection"
        })
        |> Ash.create!(authorize?: false)
        |> Ash.Changeset.for_update(:mark_success, %{})
        |> Ash.update!(authorize?: false)

      :ok = Emakola.Payments.ProtectionHolds.ensure_hold(payment)

      {:ok, hold} =
        Emakola.Payments.get_protection_hold_by_payment(payment.id,
          tenant: store.id,
          authorize?: false
        )

      assert is_nil(hold.release_after)

      assert :ok = FulfillmentWorker.perform(%Oban.Job{args: %{"order_id" => order.id}})

      {:ok, reloaded} =
        Emakola.Payments.get_protection_hold_by_payment(payment.id,
          tenant: store.id,
          authorize?: false
        )

      refute is_nil(reloaded.release_after)
    end
  end
end
