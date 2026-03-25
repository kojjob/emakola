defmodule Emakola.Payments.Workers.HubtelWebhookHandler do
  @moduledoc """
  Oban worker for processing Hubtel payment webhooks.

  Receives webhook data, verifies the transaction by calling Hubtel's
  status check API via the Gateway, and delegates to HubtelWebhook
  for payment/order record updates.

  Idempotent: safe to process the same webhook multiple times.
  """

  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    unique: [period: 300, keys: [:client_reference]]

  alias Emakola.Payments.Gateways.Hubtel
  alias Emakola.Payments.HubtelWebhook

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"client_reference" => reference} = args}) do
    case Hubtel.verify_payment(reference) do
      {:ok, %{status: status}} when status in [:paid, :completed] ->
        event = %{
          "ResponseCode" => "0000",
          "Data" => %{
            "ClientReference" => reference,
            "Amount" => args["amount"]
          }
        }

        HubtelWebhook.handle_event(event)

      {:ok, %{status: _other_status}} ->
        event = %{
          "ResponseCode" => "4001",
          "Data" => %{
            "ClientReference" => reference,
            "Message" => "Payment not completed"
          }
        }

        HubtelWebhook.handle_event(event)

      {:error, _reason} ->
        {:error, :verification_failed}
    end
  end
end
