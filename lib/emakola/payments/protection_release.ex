defmodule Emakola.Payments.ProtectionRelease do
  @moduledoc """
  Releases a buyer-protection hold, paying the merchant the snapshotted net
  through the existing payout engine (TC-2).

  `release/2` runs one transaction: the hold's `:release` action (stamping
  `release_reason`), then the payment's `:release_payout_hold` action —
  passed the hold's snapshotted `net` as `payable_amount` — which clears
  `payout_held` so the payment re-enters `PayoutService`'s backlog. Because
  `net` was snapshotted at hold-creation time (`ProtectionHolds.ensure_hold/1`),
  release pays exactly that amount regardless of any later change to the
  configured platform fee rate.

  Idempotent: releasing an already-released hold is a no-op returning `:ok`
  without touching the payment again. The hold's `:release` action (only
  reachable from `:held`) is a backstop against a stale caller, not the
  primary idempotency check.
  """

  alias Emakola.Payments
  alias Emakola.Payments.Payment

  @doc """
  Release `hold` for `reason` (`:delivery_otp | :buyer_confirmed | :auto_timer | :staff`).

  Returns `:ok` or `{:error, term}`.
  """
  def release(hold, reason)

  def release(%{status: :released}, _reason), do: :ok

  def release(hold, reason) do
    Emakola.Repo.transaction(fn ->
      with {:ok, released_hold} <-
             Payments.release_protection_hold(hold, %{release_reason: reason}, authorize?: false),
           payment <- Ash.get!(Payment, released_hold.payment_id, authorize?: false),
           {:ok, _payment} <-
             payment
             |> Ash.Changeset.for_update(:release_payout_hold, %{
               payable_amount: released_hold.net
             })
             |> Ash.update(authorize?: false) do
        :ok
      else
        {:error, error} -> Emakola.Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, :ok} -> :ok
      {:error, error} -> {:error, error}
    end
  end
end
