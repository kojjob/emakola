defmodule Emakola.Payments.Workers.ProtectionReleaseWorker do
  @moduledoc """
  Releases a buyer-protection hold (TC-2) outside the caller's transaction.

  `ProtectionRelease.release/2,3` opens its own `Repo.transaction` and calls
  `Repo.rollback` on failure. Called synchronously from a hook on
  `FulfillmentDeliveryProof.:verify`, that nested transaction+rollback can
  break the caller's own transaction: `Suppliers.InboundFulfillment.verify_delivery/4`
  wraps `:verify` in its own `Repo.transaction`, and Ecto's nested
  `Repo.transaction` calls share the outer connection rather than opening a
  real savepoint. A `Repo.rollback` from inside that nested call leaves the
  shared connection unable to run the caller's next query — even though the
  release failure itself was caught and logged, `mark_fulfillment_delivered!`
  (the very next statement in `verify_and_deliver!/1`) then raises on the
  poisoned connection, tearing down the entire verification.

  This worker decouples release from any caller's transaction entirely: the
  `:verify` hook only enqueues this job — a plain `Oban.insert`, safe inside
  any transaction because it never calls `Repo.rollback` (see
  `Emakola.Orders.Changes.ReleaseProtectionHoldOnVerify`) — and the release
  itself runs later, in this worker's own connection, where a rollback can
  never touch anyone else's work.

  Re-checks "are all of the order's fulfillments delivered/verified" at run
  time rather than trusting a snapshot taken when the job was enqueued — by
  the time this runs, sibling fulfillments may have confirmed too (or not
  yet), so re-checking is both simpler and fresher than smuggling that state
  through job args.

  Idempotent: `ProtectionHolds.release_for_order/3` no-ops when there's no
  hold to release, and `ProtectionRelease.release/2,3` no-ops on an
  already-released (or, by default, frozen) hold via its `FOR UPDATE`-locked
  fresh read — so re-running this job (an Oban retry, the `unique` dedup
  window lapsing, or a second fulfillment's verify enqueueing again) is
  always safe.
  """

  use Oban.Worker, queue: :default, max_attempts: 3, unique: [period: 600, fields: [:args]]

  require Ash.Query

  alias Emakola.Orders.Fulfillment
  alias Emakola.Payments.ProtectionHolds

  @release_reasons [:delivery_otp, :buyer_confirmed, :auto_timer, :staff]

  @spec enqueue(binary(), binary(), atom()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(order_id, store_id, reason)
      when is_binary(order_id) and is_binary(store_id) and reason in @release_reasons do
    %{"order_id" => order_id, "store_id" => store_id, "reason" => Atom.to_string(reason)}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"order_id" => order_id, "store_id" => store_id, "reason" => reason}
      }) do
    if all_fulfillments_delivered?(order_id, store_id) do
      ProtectionHolds.release_for_order(order_id, store_id, reason_atom(reason))
    else
      :ok
    end
  end

  defp reason_atom(reason),
    do: Emakola.SafeAtom.to_atom_in(reason, @release_reasons, :delivery_otp)

  defp all_fulfillments_delivered?(order_id, store_id) do
    Fulfillment
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.load(:delivery_proof)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> Enum.all?(&delivered_or_verified?/1)
  end

  defp delivered_or_verified?(%Fulfillment{status: :delivered}), do: true

  defp delivered_or_verified?(%Fulfillment{delivery_proof: %{verified_at: verified_at}}),
    do: not is_nil(verified_at)

  defp delivered_or_verified?(_fulfillment), do: false
end
