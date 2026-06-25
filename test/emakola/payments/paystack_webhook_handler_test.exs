defmodule Emakola.Payments.Workers.PaystackWebhookHandlerTest do
  use Emakola.DataCase, async: true
  use Oban.Testing, repo: Emakola.Repo

  require Ash.Query

  alias Emakola.Payments.Payment
  alias Emakola.Payments.Workers.PaystackWebhookHandler

  import Emakola.Factory

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  describe "charge.success event" do
    test "marks payment as success", %{store: store} do
      payment = create_payment!(store)

      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 500_000,
          "currency" => "GHS",
          "status" => "success",
          "gateway_response" => "Successful",
          "channel" => "mobile_money"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :success
      assert updated.gateway_response["gateway_response"] == "Successful"
    end
  end

  describe "charge.failed event" do
    test "marks payment as failed", %{store: store} do
      payment = create_payment!(store)

      event = %{
        "event" => "charge.failed",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 500_000,
          "currency" => "GHS",
          "status" => "failed",
          "gateway_response" => "Declined"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :failed
    end
  end

  describe "refund.processed event" do
    test "marks payment as refunded", %{store: store} do
      payment = create_payment!(store)

      # First mark as success
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
  end

  describe "idempotency" do
    test "processing same charge.success event twice is safe", %{store: store} do
      payment = create_payment!(store)

      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 500_000,
          "status" => "success",
          "gateway_response" => "Successful"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert :ok = perform_job(PaystackWebhookHandler, event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :success
    end

    test "skips if payment already in terminal state", %{store: store} do
      payment = create_payment!(store)

      # Mark as failed first
      payment
      |> Ash.Changeset.for_update(:mark_failed, %{
        gateway_response: %{"status" => "failed"}
      })
      |> Ash.update!(authorize?: false)

      # Try to process a success event — should be idempotent, skip
      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 500_000,
          "status" => "success",
          "gateway_response" => "Successful"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      # Should still be failed — not overwritten
      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :failed
    end
  end

  describe "unknown events" do
    test "ignores unknown event types" do
      event = %{
        "event" => "subscription.disable",
        "data" => %{"reference" => "some-ref"}
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)
    end
  end

  describe "missing payment" do
    test "returns error when payment not found" do
      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => "PAY-nonexistent-ref",
          "status" => "success",
          "gateway_response" => "Successful"
        }
      }

      assert {:error, :payment_not_found} = perform_job(PaystackWebhookHandler, event)
    end
  end

  describe "transfer.success event" do
    test "marks the matching payout paid", %{store: store} do
      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 80_000, transfer_reference: "po_wh_success"},
          authorize?: false
        )

      event = %{
        "event" => "transfer.success",
        "data" => %{
          "reference" => "po_wh_success",
          "transfer_code" => "TRF_x",
          "status" => "success"
        }
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert Emakola.Payments.get_payout!(payout.id, authorize?: false).status == :paid

      assert_enqueued(
        worker: Emakola.Notifications.Workers.PayoutNotificationWorker,
        args: %{"payout_id" => payout.id}
      )
    end

    test "ignores a reference that is not one of our payouts" do
      event = %{"event" => "transfer.success", "data" => %{"reference" => "po_unknown"}}
      assert :ok = perform_job(PaystackWebhookHandler, event)
    end
  end

  describe "transfer.failed event" do
    test "marks the matching payout failed", %{store: store} do
      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 80_000, transfer_reference: "po_wh_failed"},
          authorize?: false
        )

      event = %{
        "event" => "transfer.failed",
        "data" => %{"reference" => "po_wh_failed", "status" => "failed"}
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert Emakola.Payments.get_payout!(payout.id, authorize?: false).status == :failed
    end

    test "a failed transfer releases the covered charges back to outstanding (no buried balance)",
         %{store: store} do
      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 80_000, transfer_reference: "po_release"},
          authorize?: false
        )

      charges =
        for amount <- [30_000, 50_000] do
          store
          |> create_payment!(amount: amount)
          |> Ash.Changeset.for_update(:mark_success, %{})
          |> Ash.update!(authorize?: false)
          |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout.id})
          |> Ash.update!(authorize?: false)
        end

      event = %{
        "event" => "transfer.failed",
        "data" => %{"reference" => "po_release", "status" => "failed"}
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)
      assert Emakola.Payments.get_payout!(payout.id, authorize?: false).status == :failed

      for charge <- charges do
        reloaded =
          Payment |> Ash.Query.filter(id == ^charge.id) |> Ash.read_one!(authorize?: false)

        assert is_nil(reloaded.paid_out_at)
        assert is_nil(reloaded.payout_id)
      end
    end

    test "transfer.failed re-runs the release after a crash mid-loop (payout already :failed)",
         %{store: store} do
      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 50_000, transfer_reference: "po_crash"},
          authorize?: false
        )

      charge = stamped_charge!(store, 50_000, payout)

      # Simulate a prior attempt that committed mark_failed but crashed BEFORE
      # releasing the charge — the payout is already :failed, the charge stamped.
      {:ok, _} =
        Emakola.Payments.mark_payout_failed(payout, %{failure_reason: "x"}, authorize?: false)

      event = %{
        "event" => "transfer.failed",
        "data" => %{"reference" => "po_crash", "status" => "failed"}
      }

      assert :ok = perform_job(PaystackWebhookHandler, event)

      reloaded = Payment |> Ash.Query.filter(id == ^charge.id) |> Ash.read_one!(authorize?: false)
      assert is_nil(reloaded.payout_id)
      assert is_nil(reloaded.paid_out_at)
    end

    test "transfer.reversed after a success un-pays the payout and releases the balance",
         %{store: store} do
      payout =
        Emakola.Payments.create_payout!(
          %{store_id: store.id, amount: 50_000, transfer_reference: "po_rev"},
          authorize?: false
        )

      charge = stamped_charge!(store, 50_000, payout)

      assert :ok =
               perform_job(PaystackWebhookHandler, %{
                 "event" => "transfer.success",
                 "data" => %{"reference" => "po_rev", "status" => "success"}
               })

      assert Emakola.Payments.get_payout!(payout.id, authorize?: false).status == :paid

      # The gateway claws the money back after success — un-pay + release.
      assert :ok =
               perform_job(PaystackWebhookHandler, %{
                 "event" => "transfer.reversed",
                 "data" => %{"reference" => "po_rev", "status" => "reversed"}
               })

      assert Emakola.Payments.get_payout!(payout.id, authorize?: false).status == :reversed

      reloaded = Payment |> Ash.Query.filter(id == ^charge.id) |> Ash.read_one!(authorize?: false)
      assert is_nil(reloaded.payout_id)
    end
  end

  defp stamped_charge!(store, amount, payout) do
    store
    |> create_payment!(amount: amount)
    |> Ash.Changeset.for_update(:mark_success, %{})
    |> Ash.update!(authorize?: false)
    |> Ash.Changeset.for_update(:mark_paid_out, %{payout_id: payout.id})
    |> Ash.update!(authorize?: false)
  end
end
