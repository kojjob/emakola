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

  # TODO: Update to use PaystackClientMock instead of HTTPClientMock
  @moduletag :pending

  import Mox
  import Emakola.Factory

  require Ash.Query

  alias Emakola.Payments.Payment
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

      assert refunded.status == :refunded
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

      event = %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => payment.gateway_reference},
          "amount" => 250_000
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :refunded
      assert updated.refunded_amount == 250_000
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
    @tag :pending
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

    @tag :pending
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

    @tag :pending
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

    @tag :pending
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
    @tag :pending
    test "full refund cancels the associated order", %{store: store} do
      order = create_order!(store)

      payment =
        create_payment!(store, %{
          amount: 500_000,
          order_id: order.id
        })

      {:ok, payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{
          gateway_response: %{"status" => "success"}
        })
        |> Ash.update(authorize?: false)

      # Process refund webhook
      event = %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => payment.gateway_reference},
          "amount" => 500_000
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      # Order should be cancelled after full refund
      # NOTE: This integration is not yet implemented in the webhook handler.
      updated_order =
        Emakola.Orders.Order
        |> Ash.Query.filter(id == ^order.id)
        |> Ash.read_one!(authorize?: false)

      assert updated_order.status == :cancelled
    end
  end
end
