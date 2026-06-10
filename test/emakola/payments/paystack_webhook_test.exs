defmodule Emakola.Payments.PaystackWebhookTest do
  use Emakola.DataCase, async: true

  require Ash.Query

  alias Emakola.Payments.Payment
  alias Emakola.Payments.PaystackWebhook

  import Emakola.Factory

  @secret "sk_test_default_secret"

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  # -- verify_signature/2 ---------------------------------------------------

  describe "verify_signature/2" do
    test "returns :ok with valid HMAC SHA-512 signature" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})

      signature =
        :crypto.mac(:hmac, :sha512, @secret, body)
        |> Base.encode16(case: :lower)

      assert :ok = PaystackWebhook.verify_signature(body, signature)
    end

    test "returns error with invalid signature" do
      body = ~s({"event":"charge.success","data":{"reference":"ref123"}})

      assert {:error, :invalid_signature} =
               PaystackWebhook.verify_signature(body, "invalid_signature_here")
    end

    test "returns error when signature is nil" do
      body = ~s({"event":"charge.success"})

      assert {:error, :invalid_signature} = PaystackWebhook.verify_signature(body, nil)
    end

    test "returns error when signature is empty string" do
      body = ~s({"event":"charge.success"})

      assert {:error, :invalid_signature} = PaystackWebhook.verify_signature(body, "")
    end

    test "rejects signature computed with wrong key" do
      body = ~s({"event":"charge.success"})

      wrong_sig =
        :crypto.mac(:hmac, :sha512, "wrong_secret_key", body)
        |> Base.encode16(case: :lower)

      assert {:error, :invalid_signature} = PaystackWebhook.verify_signature(body, wrong_sig)
    end
  end

  # -- handle_event/1: charge.success --------------------------------------

  describe "handle_event/1 charge.success" do
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

      assert :ok = PaystackWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :success
      assert updated.gateway_response["gateway_response"] == "Successful"
    end

    test "returns error when payment not found" do
      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => "PAY-nonexistent-ref",
          "status" => "success",
          "gateway_response" => "Successful"
        }
      }

      assert {:error, :payment_not_found} = PaystackWebhook.handle_event(event)
    end
  end

  # -- handle_event/1: charge.failed ----------------------------------------

  describe "handle_event/1 charge.failed" do
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

      assert :ok = PaystackWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :failed
    end
  end

  # -- handle_event/1: refund.processed ------------------------------------

  describe "handle_event/1 refund.processed" do
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

      assert :ok = PaystackWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :refunded
      assert updated.refunded_amount == 250_000
    end
  end

  # -- handle_event/1: unknown events --------------------------------------

  describe "handle_event/1 unknown events" do
    test "ignores unknown event types" do
      event = %{
        "event" => "transfer.success",
        "data" => %{"reference" => "some-ref"}
      }

      assert :ok = PaystackWebhook.handle_event(event)
    end

    test "ignores completely unrecognized payloads" do
      assert :ok = PaystackWebhook.handle_event(%{"something" => "else"})
    end
  end

  # -- idempotency ----------------------------------------------------------

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

      assert :ok = PaystackWebhook.handle_event(event)
      assert :ok = PaystackWebhook.handle_event(event)

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

      # Try to process a success event — should be idempotent
      event = %{
        "event" => "charge.success",
        "data" => %{
          "reference" => payment.gateway_reference,
          "amount" => 500_000,
          "status" => "success",
          "gateway_response" => "Successful"
        }
      }

      assert :ok = PaystackWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      # Should still be failed — not overwritten
      assert updated.status == :failed
    end

    test "refund.processed is idempotent for already-refunded payment", %{store: store} do
      payment = create_payment!(store)

      {:ok, successful_payment} =
        payment
        |> Ash.Changeset.for_update(:mark_success, %{gateway_response: %{}})
        |> Ash.update(authorize?: false)

      successful_payment
      |> Ash.Changeset.for_update(:mark_refunded, %{refunded_amount: 250_000})
      |> Ash.update!(authorize?: false)

      event = %{
        "event" => "refund.processed",
        "data" => %{
          "transaction" => %{"reference" => payment.gateway_reference},
          "amount" => 250_000
        }
      }

      assert :ok = PaystackWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :refunded
      # Amount unchanged from first refund
      assert updated.refunded_amount == 250_000
    end
  end
end
