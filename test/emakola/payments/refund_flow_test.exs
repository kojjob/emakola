defmodule Emakola.Payments.RefundFlowTest do
  @moduledoc """
  Tests for the complete refund lifecycle across gateway and domain layers.

  Covers:
  - Successful full and partial refunds via Paystack and Hubtel
  - Refund amount validation (cannot refund more than paid)
  - Idempotency (cannot double-refund)
  - Payment status transitions during refund
  - Refund webhook processing updates payment records
  """

  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  import Mox
  import Emakola.Factory

  require Ash.Query

  alias Emakola.Payments.Payment
  alias Emakola.Payments.RefundReconciliation
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  setup :verify_on_exit!

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  # ── Payment Status Transitions for Refunds ────────────────────────

  describe "mark_refunded action" do
    test "transitions a successful payment to refunded with full amount", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})

      # First mark as success (required before refund)
      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success"}
        })
        |> Ash.update(authorize?: false)

      assert payment.status == :success

      # Now refund the full amount
      {:ok, refunded} =
        payment
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 500_000})
        |> Ash.update(authorize?: false)

      assert refunded.status == :refunded
      assert refunded.refunded_amount == 500_000
    end

    test "tracks partial refund amount correctly", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})

      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success"}
        })
        |> Ash.update(authorize?: false)

      # Partial refund — only 200,000 pesewas of 500,000
      {:ok, refunded} =
        payment
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 200_000})
        |> Ash.update(authorize?: false)

      # A partial refund keeps the payment :success so further partials can
      # still be recorded; only a full refund flips it to :refunded.
      assert refunded.status == :success
      assert refunded.refunded_amount == 200_000
      # Original amount unchanged
      assert refunded.amount == 500_000
    end

    test "refunded_amount defaults to 0 on a new payment", %{store: store} do
      payment = create_payment!(store)
      assert payment.refunded_amount == 0
    end
  end

  # ── Refund via Paystack Gateway ────────────────────────────────────

  describe "Paystack process_refund/2" do
    test "returns processed refund with correct amount" do
      reference = "PAY-refund-test-ref"
      refund_amount = 300_000

      Emakola.Payments.PaystackClientMock
      |> expect(:create_refund, fn params ->
        assert params.transaction == reference
        assert params.amount == refund_amount

        {:ok,
         %{
           "status" => true,
           "data" => %{
             "transaction" => %{"reference" => reference},
             "amount" => refund_amount,
             "status" => "processed",
             "refund_reference" => "refund-paystack-001"
           }
         }}
      end)

      assert {:ok, result} =
               Emakola.Payments.Gateways.Paystack.process_refund(reference, refund_amount)

      assert result.status == :processed
      assert result.amount == refund_amount
      assert result.reference == reference
      assert result.refund_reference == "refund-paystack-001"
    end

    test "returns pending status for refund awaiting processing" do
      Emakola.Payments.PaystackClientMock
      |> expect(:create_refund, fn _params ->
        {:ok,
         %{
           "status" => true,
           "data" => %{
             "transaction" => %{"reference" => "PAY-pending-refund"},
             "amount" => 100_000,
             "status" => "pending",
             "refund_reference" => "refund-pending-001"
           }
         }}
      end)

      assert {:ok, result} =
               Emakola.Payments.Gateways.Paystack.process_refund("PAY-pending-refund", 100_000)

      assert result.status == :pending
    end

    test "returns error when Paystack rejects the refund" do
      Emakola.Payments.PaystackClientMock
      |> expect(:create_refund, fn _params ->
        {:ok,
         %{
           "status" => false,
           "message" => "Transaction has already been fully reversed"
         }}
      end)

      assert {:error, {:paystack_error, "Transaction has already been fully reversed"}} =
               Emakola.Payments.Gateways.Paystack.process_refund("PAY-already-refunded", 100_000)
    end
  end

  # ── Refund via Hubtel Gateway ──────────────────────────────────────

  describe "Hubtel process_refund/2" do
    test "returns :not_supported error (Hubtel refunds are manual)" do
      assert {:error, :not_supported} =
               Emakola.Payments.Gateways.Hubtel.process_refund("HUB-refund-ref", 500_000)
    end
  end

  # ── Refund Webhook Processing ──────────────────────────────────────

  describe "refund.processed webhook via PaystackWebhookHandler" do
    test "updates payment to refunded status with refund amount", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})

      # Payment must be successful before refund
      payment
      |> Ash.Changeset.for_update(:mark_success, %{
        gateway_response: %{"status" => "success"}
      })
      |> Ash.update!(authorize?: false)

      # Full refund (payment amount is 500_000) -> :refunded.
      event = %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => payment.gateway_reference},
          "amount" => 500_000
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :refunded
      assert updated.refunded_amount == 500_000
    end

    test "idempotent — processing refund.processed twice does not error", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})

      payment
      |> Ash.Changeset.for_update(:mark_success, %{
        gateway_response: %{"status" => "success"}
      })
      |> Ash.update!(authorize?: false)

      event = %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => payment.gateway_reference},
          "amount" => 500_000
        }
      }

      # Process twice — second call should be safely idempotent
      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert :ok = perform_job(PaystackWebhookHandler, event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :refunded
    end

    test "refund webhook for unknown payment returns error" do
      event = %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => "PAY-nonexistent-ref"},
          "amount" => 100_000
        }
      }

      assert {:error, :payment_not_found} = perform_job(PaystackWebhookHandler, event)
    end
  end

  # ── Refund Business Rules (Domain Level) ───────────────────────────

  describe "refund business rules" do
    test "cannot refund more than the original payment amount", %{store: store} do
      payment = create_payment!(store, %{amount: 100_000})

      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success"}
        })
        |> Ash.update(authorize?: false)

      # Attempting to refund more than paid should fail
      # NOTE: This validation is not yet implemented in the mark_refunded action.
      # This test documents the expected behavior for when it is added.
      assert {:error, _reason} =
               payment
               |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 200_000})
               |> Ash.update(authorize?: false)
    end

    test "cannot refund an already refunded payment", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})

      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success"}
        })
        |> Ash.update(authorize?: false)

      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 500_000})
        |> Ash.update(authorize?: false)

      assert payment.status == :refunded

      # Attempting to refund again should fail
      # NOTE: Not yet enforced — the mark_refunded action does not validate
      # that the payment isn't already in :refunded status.
      assert {:error, _reason} =
               payment
               |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 500_000})
               |> Ash.update(authorize?: false)
    end

    test "cannot refund a pending payment", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})
      assert payment.status == :pending

      # Should not be able to refund a payment that hasn't succeeded
      # NOTE: Not yet enforced in the mark_refunded action.
      assert {:error, _reason} =
               payment
               |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 500_000})
               |> Ash.update(authorize?: false)
    end

    test "cannot refund a failed payment", %{store: store} do
      payment = create_payment!(store, %{amount: 500_000})

      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_failed, %{
          gateway_response: %{"status" => "failed"}
        })
        |> Ash.update(authorize?: false)

      assert payment.status == :failed

      # Should not be able to refund a failed payment
      # NOTE: Not yet enforced in the mark_refunded action.
      assert {:error, _reason} =
               payment
               |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 500_000})
               |> Ash.update(authorize?: false)
    end
  end

  # ── Refund + Order Status Integration ──────────────────────────────

  describe "refund and order status" do
    test "full refund cancels an unfulfilled order and its pending fulfillments", %{
      store: store
    } do
      order = create_order!(store)
      fulfillment = create_fulfillment!(order, store)

      payment = successful_payment!(store, order.id)
      assert :ok = perform_job(PaystackWebhookHandler, refund_event(payment, payment.amount))

      assert reload_order(order).status == :cancelled
      assert reload_fulfillment(fulfillment).status == :cancelled
    end

    # A declined group is still work the merchant owes the buyer, so a full
    # refund must cancel it. This is also the tripwire for the coupling between
    # RefundReconciliation's @active_fulfillment_statuses and Fulfillment's
    # :cancel `from:` list — if they drift, the Ash.update! raises INSIDE the
    # transaction and reconciliation fails for the entire order, not just this
    # group.
    test "full refund cancels a declined fulfillment without raising", %{store: store} do
      order = create_order!(store)
      supplier = create_supplier!(store)
      declined = create_fulfillment!(order, store, supplier_id: supplier.id)

      {:ok, declined} =
        Emakola.Orders.supplier_decline_fulfillment(
          declined,
          %{decline_reason: :out_of_stock},
          authorize?: false
        )

      assert declined.status == :declined

      payment = successful_payment!(store, order.id)
      assert :ok = perform_job(PaystackWebhookHandler, refund_event(payment, payment.amount))

      assert reload_order(order).status == :cancelled
      assert reload_fulfillment(declined).status == :cancelled
    end

    test "a partial refund leaves order and fulfillment state unchanged", %{store: store} do
      order = create_order!(store, status: :confirmed)
      fulfillment = create_fulfillment!(order, store)
      payment = successful_payment!(store, order.id)

      assert :ok = perform_job(PaystackWebhookHandler, refund_event(payment, 200_000))

      assert reload_payment(payment).status == :success
      assert reload_payment(payment).refunded_amount == 200_000
      assert reload_order(order).status == :confirmed
      assert reload_fulfillment(fulfillment).status == :pending
    end

    for status <- [:shipped, :delivered] do
      test "a full refund preserves #{status} order and fulfillment history", %{store: store} do
        status = unquote(status)
        order = create_order!(store, status: status)
        fulfillment = create_fulfillment!(order, store, status: status)
        payment = successful_payment!(store, order.id)

        assert :ok = perform_job(PaystackWebhookHandler, refund_event(payment, payment.amount))

        assert reload_payment(payment).status == :refunded
        assert reload_order(order).status == status
        assert reload_fulfillment(fulfillment).status == status
      end
    end

    test "one shipped fulfillment preserves the whole operational history", %{store: store} do
      order = create_order!(store, status: :processing)
      shipped = create_fulfillment!(order, store, status: :shipped)
      pending = create_fulfillment!(order, store, status: :pending)
      payment = successful_payment!(store, order.id)

      assert :ok = perform_job(PaystackWebhookHandler, refund_event(payment, payment.amount))

      assert reload_order(order).status == :processing
      assert reload_fulfillment(shipped).status == :shipped
      assert reload_fulfillment(pending).status == :pending
    end

    test "stable refund identifiers make partial webhook replays idempotent", %{store: store} do
      order = create_order!(store, status: :confirmed)
      payment = successful_payment!(store, order.id)

      event = refund_event(payment, 200_000, "refund-partial-001")

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert :ok = perform_job(PaystackWebhookHandler, event)

      assert reload_payment(payment).status == :success
      assert reload_payment(payment).refunded_amount == 200_000
      assert reload_order(order).status == :confirmed
    end

    test "full-refund replay restores stock exactly once", %{store: store} do
      product = create_product!(store)

      variant =
        create_variant!(product, store, %{price: 5_000, stock_quantity: 10, track_inventory: true})

      {:ok, order} =
        Emakola.Orders.CheckoutService.checkout!(
          store.id,
          [%{variant_id: variant.id, quantity: 2}],
          []
        )

      {:ok, _confirmed} = Emakola.Orders.confirm_order(order, authorize?: false)
      assert reload_variant(variant).stock_quantity == 8

      payment = successful_payment!(store, order.id, order.total)
      event = refund_event(payment, payment.amount, "refund-full-stock-001")

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert reload_order(order).status == :cancelled
      assert reload_variant(variant).stock_quantity == 10

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert reload_variant(variant).stock_quantity == 10

      refund_movements =
        Emakola.Inventory.StockMovement
        |> Ash.Query.filter(order_id == ^order.id and reason == :refund)
        |> Ash.read!(authorize?: false)

      assert Enum.sum(Enum.map(refund_movements, & &1.delta)) == 2
    end

    test "refund reconciliation serializes payment and order decisions with row locks", %{
      store: store
    } do
      payment_sql =
        RefundReconciliation.locked_payment_query("PAY-lock-test")
        |> then(&Ecto.Adapters.SQL.to_sql(:all, Emakola.Repo, &1))
        |> elem(0)

      order_sql =
        Emakola.Orders.RefundReconciliation.locked_order_query(Ash.UUID.generate(), store.id)
        |> then(&Ecto.Adapters.SQL.to_sql(:all, Emakola.Repo, &1))
        |> elem(0)

      assert payment_sql =~ "FOR UPDATE"
      assert order_sql =~ "FOR UPDATE"
    end
  end

  defp successful_payment!(store, order_id, amount \\ 500_000) do
    store
    |> create_payment!(%{amount: amount, order_id: order_id})
    |> Ash.Changeset.for_update(:mark_success, %{
      gateway_response: %{"status" => "success"}
    })
    |> Ash.update!(authorize?: false)
  end

  defp refund_event(payment, amount, refund_reference \\ nil) do
    data = %{
      "transaction" => %{"reference" => payment.gateway_reference},
      "amount" => amount
    }

    data =
      if refund_reference do
        Map.put(data, "refund_reference", refund_reference)
      else
        data
      end

    %{"event" => "refund.processed", "data" => data}
  end

  defp reload_payment(payment), do: Ash.get!(Payment, payment.id, authorize?: false)

  defp reload_order(order) do
    Ash.get!(Emakola.Orders.Order, order.id, authorize?: false)
  end

  defp reload_fulfillment(fulfillment) do
    Ash.get!(Emakola.Orders.Fulfillment, fulfillment.id, authorize?: false)
  end

  defp reload_variant(variant) do
    Ash.get!(Emakola.Catalog.Variant, variant.id, authorize?: false)
  end
end
