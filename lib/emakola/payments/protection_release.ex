defmodule Emakola.Payments.ProtectionRelease do
  @moduledoc """
  Releases a buyer-protection hold, paying the merchant the snapshotted net
  through the existing payout engine (TC-2).

  `release/2` runs one transaction with a `FOR UPDATE` lock on the hold's row
  — the same claim pattern as `Emakola.Orders.PayLinkClaim` — so two
  concurrent release triggers (e.g. the auto-release timer firing alongside a
  buyer confirming delivery) can never both win: the second to acquire the
  lock re-reads the row fresh and finds it already `:released`, so it no-ops
  instead of overwriting `release_reason`/`released_at`/`payout_released_at`
  with its own values.

  On the winning path: the hold's `:release` action (stamping
  `release_reason`), then the payment's `:release_payout_hold` action —
  passed the hold's snapshotted `net` as `payable_amount` — which clears
  `payout_held` so the payment re-enters `PayoutService`'s backlog. Because
  `net` was snapshotted at hold-creation time (`ProtectionHolds.ensure_hold/1`),
  release pays exactly that amount regardless of any later change to the
  configured platform fee rate.

  ## Freeze respect

  A frozen hold (`frozen_at` set — an open buyer complaint) is, by default,
  left `:held` rather than released: `respect_freeze: true` is the default
  for `release/2,3` so every trigger written against this module — the OTP
  hook, the buyer's own tracking-page confirmation, the auto-release timer —
  automatically defers to an open complaint without having to know about
  `frozen_at` itself. The one caller that must be able to override it is
  platform staff force-releasing a frozen hold after resolving the
  complaint out-of-band; that call site passes `respect_freeze: false`
  explicitly. The check reads `frozen_at` off the same `FOR UPDATE`-locked
  fresh row the idempotency check already reads, so it costs no extra query
  and can't race a concurrent freeze.
  """

  import Ecto.Query, only: [from: 2]

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Payments
  alias Emakola.Payments.Payment
  alias Emakola.Repo

  # Builds the FOR-UPDATE row lookup used by `release/2`. Exposed (not
  # private) so `ProtectionReleaseTest` can pass it to
  # `Ecto.Adapters.SQL.to_sql/3` and assert the lock clause is present — a
  # deterministic, non-flaky guard against someone dropping `lock: "FOR
  # UPDATE"` (mirrors `PayLinkClaim.locked_row_query/1`).
  @doc false
  def locked_row_query(hold_id) do
    from(h in "protection_holds",
      where: h.id == type(^hold_id, :binary_id),
      lock: "FOR UPDATE",
      select: %{status: h.status, frozen_at: h.frozen_at}
    )
  end

  @doc """
  Release `hold` for `reason` (`:delivery_otp | :buyer_confirmed | :auto_timer | :staff`).

  Returns `:ok` or `{:error, term}`. Idempotent: releasing an already-released
  hold is a no-op returning `:ok` without touching the payment again — decided
  on a `FOR UPDATE`-locked fresh read of the hold row, not the (possibly
  stale) `hold` struct passed in.

  ## Options

    * `:respect_freeze` (default `true`) — when the fresh row has
      `frozen_at` set, no-op and return `:ok` instead of releasing (see
      "Freeze respect" above). Pass `respect_freeze: false` to release a
      frozen hold anyway (platform staff force-release only).

  On an actual release (not the already-released or frozen-skip no-op
  branches), dispatches `:protection_released` to the merchant (TC-2 Task
  10) — AFTER the transaction commits, never from inside the `Repo.transaction`
  closure above, matching the Dispatcher's "outside transactions" contract.
  """
  def release(hold, reason, opts \\ []) do
    respect_freeze? = Keyword.get(opts, :respect_freeze, true)

    Repo.transaction(fn ->
      case Repo.one(locked_row_query(hold.id)) do
        %{status: "released"} ->
          :noop

        %{frozen_at: frozen_at} when respect_freeze? and not is_nil(frozen_at) ->
          :noop

        _fresh ->
          with {:ok, released_hold} <-
                 Payments.release_protection_hold(hold, %{release_reason: reason},
                   authorize?: false
                 ),
               payment <- Ash.get!(Payment, released_hold.payment_id, authorize?: false),
               {:ok, _payment} <-
                 payment
                 |> Ash.Changeset.for_update(:release_payout_hold, %{
                   payable_amount: released_hold.net
                 })
                 |> Ash.update(authorize?: false) do
            :released
          else
            {:error, error} -> Repo.rollback(error)
          end
      end
    end)
    |> case do
      {:ok, :released} ->
        Dispatcher.dispatch(%{id: hold.order_id, store_id: hold.store_id}, :protection_released)
        :ok

      {:ok, :noop} ->
        :ok

      {:error, error} ->
        {:error, error}
    end
  end
end
