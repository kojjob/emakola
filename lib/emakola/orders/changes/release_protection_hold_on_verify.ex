defmodule Emakola.Orders.Changes.ReleaseProtectionHoldOnVerify do
  @moduledoc """
  After a delivery OTP verifies, enqueues the order's buyer-protection
  release (TC-2) — the strongest delivery signal available — instead of
  releasing synchronously.

  Runs `after_action`, not `after_transaction`: enqueuing here is a plain
  `Oban.insert`, which never calls `Repo.rollback` and so is safe to run
  from inside the caller's own transaction (unlike the release itself — see
  `Emakola.Payments.Workers.ProtectionReleaseWorker`'s moduledoc for why
  that must never run synchronously inside a caller's transaction). Running
  in `after_action` means the insert commits atomically WITH the verify —
  Oban's transactional-insert pattern — so the job only ever becomes
  visible if the verify actually committed; no separate "did it really
  happen" bookkeeping needed.

  Only enqueues when a cheap, single-query check finds an actively `:held`
  hold for this order. Most delivery-OTP verifications are for unprotected
  orders, and there's no reason to create Oban job noise — or pay for the
  multi-fulfillment "are they all delivered" scan, which the worker
  re-checks anyway — for every one of them.

  An enqueue failure is logged and swallowed — it must never fail the OTP
  verification the buyer is standing in front of a courier waiting on.
  """

  use Ash.Resource.Change

  require Logger

  alias Emakola.Orders.Fulfillment
  alias Emakola.Payments.ProtectionHolds
  alias Emakola.Payments.Workers.ProtectionReleaseWorker

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, proof ->
      enqueue_release(proof)
      {:ok, proof}
    end)
  end

  defp enqueue_release(proof) do
    fulfillment = Ash.get!(Fulfillment, proof.fulfillment_id, authorize?: false)

    if ProtectionHolds.active_hold_for_order?(fulfillment.order_id, fulfillment.store_id) do
      case ProtectionReleaseWorker.enqueue(
             fulfillment.order_id,
             fulfillment.store_id,
             :delivery_otp
           ) do
        {:ok, _job} ->
          :ok

        {:error, error} ->
          Logger.error(
            "[delivery_otp] protection release enqueue failed for order=#{fulfillment.order_id}: " <>
              inspect(error)
          )
      end
    end
  rescue
    error ->
      Logger.error(
        "[delivery_otp] protection release enqueue failed for proof=#{proof.id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )
  end
end
