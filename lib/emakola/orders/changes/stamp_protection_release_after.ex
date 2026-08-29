defmodule Emakola.Orders.Changes.StampProtectionReleaseAfter do
  @moduledoc """
  After a fulfillment reaches `:delivered`, starts the TC-2 auto-release
  timer once ALL of the order's fulfillments have delivered — multi-
  fulfillment dropship splits only confirm delivery when every one of them
  does.

  Runs `after_action`, not `after_transaction`:
  `ProtectionHolds.stamp_release_after_for_order/2` ends in a plain
  `:set_release_after` update with no explicit `Repo.transaction`/
  `Repo.rollback` of its own — unlike `ProtectionRelease.release/2,3` (see
  `Emakola.Payments.Workers.ProtectionReleaseWorker`'s moduledoc for why
  THAT must never run synchronously inside a caller's transaction) — so it
  participates safely in whatever transaction is already open, including
  the one `Suppliers.InboundFulfillment.verify_delivery/4` wraps around
  this same `:mark_delivered` action.

  Never fails the delivered transition:
  `ProtectionHolds.stamp_release_after_for_order/2` already logs-and-swallows
  internally, and the wrapping rescue here is a second line of defense
  against a failure in the "are all fulfillments delivered" check itself.
  """

  use Ash.Resource.Change

  require Ash.Query
  require Logger

  alias Emakola.Orders.Fulfillment
  alias Emakola.Payments.ProtectionHolds

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, fulfillment ->
      maybe_stamp(fulfillment)
      {:ok, fulfillment}
    end)
  end

  defp maybe_stamp(fulfillment) do
    if all_fulfillments_delivered?(fulfillment.order_id, fulfillment.store_id) do
      ProtectionHolds.stamp_release_after_for_order(fulfillment.order_id, fulfillment.store_id)
    end
  rescue
    error ->
      Logger.error(
        "[protection] stamp release_after failed for fulfillment=#{fulfillment.id}: " <>
          Exception.format(:error, error, __STACKTRACE__)
      )
  end

  defp all_fulfillments_delivered?(order_id, store_id) do
    Fulfillment
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> Enum.all?(&(&1.status == :delivered))
  end
end
