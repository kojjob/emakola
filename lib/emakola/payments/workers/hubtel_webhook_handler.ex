defmodule Emakola.Payments.Workers.HubtelWebhookHandler do
  @moduledoc """
  Oban worker for processing Hubtel payment webhooks.

  Receives webhook data, verifies the transaction by calling Hubtel's
  status check API, and updates payment/order records accordingly.

  Idempotent: safe to process the same webhook multiple times.
  """

  use Oban.Worker,
    queue: :webhooks,
    max_attempts: 5,
    unique: [period: 300, keys: [:client_reference]]

  alias Emakola.Payments.Gateways.Hubtel

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"client_reference" => reference} = _args}) do
    case Hubtel.verify_payment(reference) do
      {:ok, %{status: status}} when status in ["Paid", "Success"] ->
        # TODO: In Phase 1.5, update Payment resource to :success and Order to :confirmed
        # For now, we just verify the payment status is valid
        :ok

      {:ok, %{status: _other_status}} ->
        {:error, :verification_failed}

      {:error, _reason} ->
        {:error, :verification_failed}
    end
  end
end
