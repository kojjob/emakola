defmodule Emakola.Orders.Workers.SupplierSlaWorker do
  @moduledoc """
  Chases a supplier who has not answered, so the merchant does not have to.

  Named for the supplier rather than the fulfilment because
  `Emakola.Workers.FulfillmentWorker` already exists — the two would otherwise
  sit one word apart in every grep and stack trace.

  Queue `:default`, not `:notifications`: this worker stamps and enqueues, it
  never sends, so it keeps the five-wide notifications queue free.
  """

  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    # MUST stay strictly below the cron interval. Copying ProtectionSweepWorker's
    # 3600 onto a half-hourly cron silently swallows every second run, and no
    # test would catch it because tests call perform/1 directly. 1800 sits
    # exactly on the boundary, which is the epoch-bucket flake this codebase has
    # already been bitten by; 1500 leaves five minutes either side.
    unique: [period: 1500, fields: [:args], states: [:available, :scheduled, :executing]]

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Workers.SupplierNotificationWorker
  alias Emakola.Orders.Fulfillment

  @respond_hours 6

  # Waiting on the SUPPLIER. An accepted fulfilment leaves the ladder even
  # though its status is still :notified — hence is_nil(accepted_at) rather than
  # a status check alone. :declined and :shipped have answered; :cancelled is
  # over.
  @awaiting [:pending, :notified]

  @doc """
  Hours a supplier has to answer before the first chase.

  Single source, also read by `Emakola.Orders.Changes.StampSupplierRespondBy`
  when it starts the clock — the same shape as
  `ProtectionSweepWorker.release_days/0`.
  """
  def respond_hours, do: @respond_hours

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    escalate_all(rung_one_due(), 1, &chase_supplier/1)
    :ok
  end

  # ── Candidates ──────────────────────────────────────────────────

  defp rung_one_due do
    now = DateTime.utc_now()

    Fulfillment
    |> Ash.Query.filter(
      status in ^@awaiting and is_nil(accepted_at) and not is_nil(supplier_id) and
        escalation_level == 0 and not is_nil(respond_by) and respond_by < ^now
    )
    |> Ash.Query.limit(200)
    |> Ash.read!(authorize?: false)
  end

  # ── Escalation ──────────────────────────────────────────────────

  defp escalate_all(fulfillments, to_level, action) do
    Enum.each(fulfillments, fn fulfillment ->
      case Emakola.Orders.escalate_fulfillment(fulfillment, %{to_level: to_level},
             authorize?: false
           ) do
        {:ok, escalated} ->
          action.(escalated)

        # Someone else got there first — an Oban retry overlapping the next
        # tick. The row already moved, so there is nothing to send.
        {:error, _reason} ->
          :ok
      end
    end)
  end

  # The "escalation" arg is a real value rather than the nonce the merchant's
  # manual resend uses to DEFEAT uniqueness: here we want
  # SupplierNotificationWorker's own unique window to collapse duplicates.
  defp chase_supplier(fulfillment) do
    %{"fulfillment_id" => fulfillment.id, "escalation" => 1}
    |> SupplierNotificationWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[supplier_sla] could not enqueue chase for #{fulfillment.id}: #{inspect(reason)}"
        )

        :ok
    end
  end
end
