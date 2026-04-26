defmodule Emakola.Payments.HubtelWebhookTest do
  use Emakola.DataCase, async: true

  require Ash.Query

  alias Emakola.Payments.Payment
  alias Emakola.Payments.HubtelWebhook

  import Emakola.Factory

  setup do
    {_merchant, store} = create_merchant_with_store!()
    %{store: store}
  end

  # -- handle_event/1: successful payment ------------------------------------

  describe "handle_event/1 successful payment (ResponseCode 0000)" do
    test "marks payment as success", %{store: store} do
      payment = create_payment!(store)

      event = %{
        "ResponseCode" => "0000",
        "Data" => %{
          "ClientReference" => payment.gateway_reference,
          "Amount" => 50.0
        }
      }

      assert :ok = HubtelWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :success
      assert updated.gateway_response["response_code"] == "0000"
      assert updated.gateway_response["client_reference"] == payment.gateway_reference
    end

    test "returns error when payment not found" do
      event = %{
        "ResponseCode" => "0000",
        "Data" => %{
          "ClientReference" => "HUB-nonexistent-ref",
          "Amount" => 50.0
        }
      }

      assert {:error, :payment_not_found} = HubtelWebhook.handle_event(event)
    end
  end

  # -- handle_event/1: failed payment ----------------------------------------

  describe "handle_event/1 failed payment (non-0000 ResponseCode)" do
    test "marks payment as failed", %{store: store} do
      payment = create_payment!(store)

      event = %{
        "ResponseCode" => "4001",
        "Data" => %{
          "ClientReference" => payment.gateway_reference,
          "Message" => "Insufficient funds"
        }
      }

      assert :ok = HubtelWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      assert updated.status == :failed
      assert updated.gateway_response["response_code"] == "4001"
    end

    test "returns error when payment not found for failed event" do
      event = %{
        "ResponseCode" => "4001",
        "Data" => %{
          "ClientReference" => "HUB-nonexistent-ref",
          "Message" => "Failed"
        }
      }

      assert {:error, :payment_not_found} = HubtelWebhook.handle_event(event)
    end
  end

  # -- handle_event/1: unknown events ----------------------------------------

  describe "handle_event/1 unknown events" do
    test "ignores unrecognized payloads" do
      assert :ok = HubtelWebhook.handle_event(%{"something" => "else"})
    end

    test "ignores nil input" do
      assert :ok = HubtelWebhook.handle_event(%{})
    end
  end

  # -- idempotency -----------------------------------------------------------

  describe "idempotency" do
    test "processing same success event twice is safe", %{store: store} do
      payment = create_payment!(store)

      event = %{
        "ResponseCode" => "0000",
        "Data" => %{
          "ClientReference" => payment.gateway_reference,
          "Amount" => 50.0
        }
      }

      assert :ok = HubtelWebhook.handle_event(event)
      assert :ok = HubtelWebhook.handle_event(event)

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
        "ResponseCode" => "0000",
        "Data" => %{
          "ClientReference" => payment.gateway_reference,
          "Amount" => 50.0
        }
      }

      assert :ok = HubtelWebhook.handle_event(event)

      updated =
        Payment
        |> Ash.Query.filter(id == ^payment.id)
        |> Ash.read_one!(authorize?: false)

      # Should still be failed — not overwritten
      assert updated.status == :failed
    end
  end
end
