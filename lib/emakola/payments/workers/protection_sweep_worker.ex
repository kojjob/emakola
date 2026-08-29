defmodule Emakola.Payments.Workers.ProtectionSweepWorker do
  @moduledoc """
  Hourly cron sweep (TC-2) that releases buyer-protection holds whose
  auto-release timer has elapsed.

  `Fulfillment.:mark_delivered`'s after_action hook
  (`Emakola.Orders.Changes.StampProtectionReleaseAfter`, via
  `Emakola.Payments.ProtectionHolds.stamp_release_after_for_order/2`) stamps
  `release_after` on an order's `:held` hold — `release_days/0` days out —
  once every one of its fulfillments has delivered. This worker is the other
  half: find every hold whose timer has elapsed and release it.

  Releases directly via `ProtectionRelease.release/2` rather than delegating
  through `ProtectionReleaseWorker`: that worker's job is re-checking
  "are all of the order's fulfillments delivered" before releasing, which is
  redundant here — `release_after` is only ever stamped once every
  fulfillment has already delivered, and a delivered fulfillment doesn't
  revert, so there's nothing left to re-check. Calling `ProtectionRelease`
  directly is safe in this worker specifically because it owns its own
  connection with no ambient caller transaction to poison (the Task 6 hazard
  `ProtectionReleaseWorker` exists to route around — see that module's
  moduledoc).

  Idempotent by construction: `ProtectionRelease.release/2`'s `FOR
  UPDATE`-locked fresh read no-ops on an already-released hold, and the
  `status: :held` filter here naturally shrinks the due set every run, since
  a released hold no longer matches it — so re-running the sweep (the next
  hourly tick, an Oban retry) releases nothing twice.
  """

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 3600, fields: [:args]]

  require Ash.Query
  require Logger

  alias Emakola.Payments.ProtectionHold
  alias Emakola.Payments.ProtectionRelease

  @release_days 5

  @doc """
  Days after full delivery before an unfrozen hold auto-releases (TC-2) —
  single source, also read by `ProtectionHolds.stamp_release_after_for_order/2`
  when it starts the timer at delivery.
  """
  def release_days, do: @release_days

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    due_holds() |> Enum.each(&release_hold/1)
    :ok
  end

  defp due_holds do
    now = DateTime.utc_now()

    ProtectionHold
    |> Ash.Query.filter(status == :held and is_nil(frozen_at) and release_after < ^now)
    |> Ash.read!(authorize?: false)
  end

  defp release_hold(hold) do
    case ProtectionRelease.release(hold, :auto_timer) do
      :ok ->
        :ok

      {:error, error} ->
        Logger.error("[protection_sweep] release failed for hold=#{hold.id}: " <> inspect(error))
    end
  end
end
