defmodule Emakola.Payments.Workers.PayoutWorker do
  @moduledoc """
  Executes a prepared `Payout` — the money-moving half of the payout engine.

  Loads a pending payout, creates a Paystack transfer recipient from the store's
  MoMo details, and initiates the transfer. The payout's `transfer_reference` is
  the gateway idempotency key, so a retry never double-sends. Marks the payout
  `:processing` on success (the `transfer.success`/`transfer.failed` webhook
  finalizes it); marks `:failed` on a definitive Paystack rejection; leaves it
  `:pending` and returns `{:error, _}` on a transient error so Oban retries.

  Idempotent: only a `:pending` payout is executed; `:processing`/`:paid`/`:failed`
  are no-ops. A failed payout is terminal — its balance is released back to
  outstanding and re-paid via a fresh payout (new reference), never re-run here.

  Runs on a dedicated `:payouts` queue (a transfer can't be starved by other work)
  with a transfer timeout so a hung Paystack socket can't block the queue.
  """
  use Oban.Worker, queue: :payouts, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Logger

  @impl Oban.Worker
  def timeout(_job), do: :timer.seconds(30)

  alias Emakola.Payments
  alias Emakola.Payments.PayoutService

  @spec enqueue(binary()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(payout_id) when is_binary(payout_id) do
    %{"payout_id" => payout_id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"payout_id" => payout_id}}) do
    case Payments.get_payout(payout_id, authorize?: false, not_found_error?: false) do
      {:ok, %{status: :pending} = payout} ->
        execute(payout)

      # :processing / :paid / :failed (terminal) or nil (gone) — nothing to do.
      _ ->
        :ok
    end
  end

  defp execute(payout) do
    case PayoutService.transfer_destination(payout.store_id) do
      {:error, :no_momo_destination} ->
        mark_failed(payout, "no mobile money payout destination")
        :ok

      {:ok, dest} ->
        with {:ok, %{recipient_code: recipient_code}} <-
               gateway().create_transfer_recipient(dest),
             {:ok, %{transfer_code: transfer_code}} <-
               gateway().initiate_transfer(transfer_params(payout, recipient_code)) do
          {:ok, _} =
            Payments.mark_payout_processing(
              payout,
              %{recipient_code: recipient_code, transfer_code: transfer_code},
              authorize?: false
            )

          :ok
        else
          {:error, {:paystack_error, message}} ->
            mark_failed(payout, message)
            :ok

          {:error, reason} ->
            Logger.error(
              "[PayoutWorker] transient failure for payout #{payout.id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  defp transfer_params(payout, recipient_code) do
    %{
      source: "balance",
      amount: payout.amount,
      recipient: recipient_code,
      reason: "Makola payout",
      reference: payout.transfer_reference,
      currency: payout.currency
    }
  end

  defp mark_failed(payout, reason) do
    {:ok, _} = Payments.mark_payout_failed(payout, %{failure_reason: reason}, authorize?: false)

    # No transfer was ever created for a definitive pre-webhook rejection, so
    # no transfer.failed webhook will ever run to release this claim — release
    # it here or the claimed splits/payments are stranded (gone from payable,
    # unreachable by retry) forever. Transient errors (the `{:error, reason}`
    # retry path in execute/1) must NOT release — the payout stays :pending
    # and Oban retries the same claim.
    PayoutService.release_payout_balance(payout)
  end

  defp gateway do
    Application.get_env(:emakola, :payment_gateway, Emakola.Payments.Gateways.Paystack)
  end
end
