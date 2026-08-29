defmodule Emakola.Payments.ProtectionHolds do
  @moduledoc """
  Idempotent `ProtectionHold` creation for a webhook-confirmed payment
  (TC-2). Called from both webhook confirm sites (Paystack + Hubtel)
  immediately after the payment is marked `:success`.

  `ProtectionHold`'s unique `payment_id` identity makes a retry a no-op: a
  webhook replay or a redelivery after a crashed post-processing step simply
  hits the identity violation, which is rescued into `:ok`. Never raises into
  the calling worker.
  """

  require Ash.Query
  require Logger

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Payments
  alias Emakola.Payments.{Payment, PlatformFee, ProtectionHold, ProtectionRelease}
  alias Emakola.Payments.Workers.ProtectionSweepWorker

  @doc """
  Creates the protection hold for a payment held for buyer protection. No-op
  otherwise.

  On a genuine (non-idempotent-retry) creation, dispatches `:protection_held`
  to the buyer (TC-2 Task 10) — never fired on the identity-violation no-op
  branch below, since the `rescue` short-circuits before reaching here.
  """
  def ensure_hold(%{payout_hold_reason: "buyer_protection"} = payment) do
    %{fee: fee, net: net} = PlatformFee.calculate(payment.amount, fee_rate_bps())

    Emakola.Payments.create_protection_hold!(
      %{
        store_id: payment.store_id,
        payment_id: payment.id,
        order_id: payment.order_id,
        amount: payment.amount,
        fee: fee,
        net: net
      },
      tenant: payment.store_id,
      authorize?: false
    )

    Dispatcher.dispatch(%{id: payment.order_id, store_id: payment.store_id}, :protection_held)

    :ok
  rescue
    error ->
      if unique_payment_violation?(error) do
        :ok
      else
        Logger.error(
          "[protection_holds] ensure_hold failed for payment=#{payment.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
        )

        :ok
      end
  end

  def ensure_hold(_payment), do: :ok

  @doc """
  Stashes `resolution` on `payment.metadata["protection_resolution"]` for a
  refund request that would, if it succeeds, fully cover a `:held`
  buyer-protection hold. This is intent, not the close: the gateway
  accepting a refund request (`RefundService.issue/5`, right after
  `request_refund` succeeds) is not proof the refund actually landed —
  Paystack refund-create returns immediately with the refund still
  `pending` and resolves (or fails) asynchronously. The hold only actually
  closes once `PaystackWebhookHandler.handle_refund_processed/1` confirms
  the cumulative refund reached the full payment amount — see
  `close_for_refund/2`, which reads this stashed value back out.

  No-op when the payment carries no hold, or the hold isn't currently
  `:held`. Never fails the caller: runs inside `RefundService.issue/5`'s
  own `Repo.transaction`, and a `Payment.:update` writing a plain `:map`
  attribute has no validation that could fail on the DB side, but this
  still logs-and-swallows on any error for the same never-fail discipline
  as `ensure_hold/1`.
  """
  def stash_refund_resolution(payment, resolution) do
    case Payments.get_protection_hold_by_payment(payment.id,
           tenant: payment.store_id,
           authorize?: false
         ) do
      {:ok, %ProtectionHold{status: :held}} ->
        metadata =
          Map.put(payment.metadata || %{}, "protection_resolution", to_string(resolution))

        payment
        |> Ash.Changeset.for_update(:update, %{metadata: metadata})
        |> Ash.update(authorize?: false)
        |> case do
          {:ok, _updated} ->
            :ok

          {:error, error} ->
            Logger.error(
              "[protection_holds] stash_refund_resolution failed for payment=#{payment.id}: #{inspect(error)}"
            )

            :ok
        end

      _ ->
        :ok
    end
  rescue
    error ->
      Logger.error(
        "[protection_holds] stash_refund_resolution failed for payment=#{payment.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      :ok
  end

  @doc """
  Closes `payment`'s `:held` buyer-protection hold — called from
  `Emakola.Payments.Workers.PaystackWebhookHandler.handle_refund_processed/1`
  once `refund.processed` has confirmed the cumulative refund reached the
  full payment amount (`payment.status == :refunded`), the genuine terminal
  success state for a refund (see `stash_refund_resolution/2` for why
  `RefundService.issue/5`'s gateway-acceptance point is NOT that state).

  No-op when the payment carries no hold, or the hold isn't currently
  `:held` (nothing to close, a partial refund, or a concurrent/re-delivered
  close already ran — the webhook's own `payment.status == :refunded` guard
  already makes a second `refund.processed` delivery for the same payment
  short-circuit before this is even called again, but the `:held` check
  here is a second, independent idempotency guard).

  `resolution` defaults to `:merchant_refunded`; the caller reads it back
  from `payment.metadata["protection_resolution"]` (stashed by
  `stash_refund_resolution/2`) via a `SafeAtom` allowlist.

  Never fails the caller: called from a plain webhook-worker function with
  no ambient transaction (unlike `ProtectionRelease.release/2,3`, there is
  no manual `Repo.transaction`/`Repo.rollback` here to risk the Task 6
  poisoning bug), so a hold-close failure logging and returning `:ok`
  cannot break anything the webhook already committed.
  """
  def close_for_refund(payment, resolution \\ :merchant_refunded) do
    case Payments.get_protection_hold_by_payment(payment.id,
           tenant: payment.store_id,
           authorize?: false
         ) do
      {:ok, %ProtectionHold{status: :held} = hold} ->
        hold
        |> Payments.mark_refunded_protection_hold(%{resolution: resolution}, authorize?: false)
        |> case do
          {:ok, _closed} ->
            :ok

          {:error, error} ->
            Logger.error(
              "[protection_holds] close_for_refund failed for payment=#{payment.id}: #{inspect(error)}"
            )

            :ok
        end

      _ ->
        :ok
    end
  rescue
    error ->
      Logger.error(
        "[protection_holds] close_for_refund failed for payment=#{payment.id}: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      :ok
  end

  @doc """
  Cheap existence check: does `order_id` currently have an actively `:held`
  buyer-protection hold? A single query directly against
  `ProtectionHold.order_id` — used to gate whether a release trigger is
  worth enqueueing at all, without paying for the full payment lookup
  `release_for_order/3` does (only worth it once we know there's something
  to release) or a fulfillment scan.

  A frozen hold is still `status: :held` (freezing doesn't change status —
  see `ProtectionHold`'s moduledoc), so this returns `true` for one too;
  the actual release, once enqueued, correctly no-ops on it.
  """
  def active_hold_for_order?(order_id, store_id) do
    ProtectionHold
    |> Ash.Query.filter(order_id == ^order_id and status == :held)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> Enum.any?()
  end

  @doc """
  Fetches `order_id`'s buyer-protection hold in ANY state (`held`, and a
  `held` hold may additionally be `frozen_at`-flagged, `released`, or
  `refunded`) — for surfaces that display the current hold regardless of
  whether it's still active, e.g. the tracking page's protection strip
  (renders for every viewer once a hold exists, not just while `:held` —
  see `active_hold_for_order?/2` for the held-only existence check used to
  gate release triggers). Returns `nil` when the order was never protected.
  """
  def get_hold_for_order(order_id, store_id) do
    ProtectionHold
    |> Ash.Query.filter(order_id == ^order_id)
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> List.first()
  end

  @doc """
  Finds `order_id`'s buyer-protection hold — via its captured payment's
  `payout_hold_reason` — and releases it for `reason`.

  Returns `:ok` when the order was never protected (no captured payment
  carries the `"buyer_protection"` hold reason, or the payment has no hold
  row): an ordinary outcome for the vast majority of orders, not a failure.
  Otherwise returns whatever `ProtectionRelease.release/2` returns — release
  itself already treats "already released" and (by default) frozen holds as
  no-op `:ok`s, so an `{:error, _}` here is a genuine failure worth the
  caller logging.

  Shared by every order-level release trigger (delivery-OTP verification;
  the buyer's own tracking-page confirmation) so the payment→hold lookup
  lives in one place.
  """
  def release_for_order(order_id, store_id, reason) do
    with {:ok, payments} <-
           Payments.list_captured_payments_by_order(order_id,
             tenant: store_id,
             authorize?: false
           ),
         %Payment{id: payment_id} <-
           Enum.find(payments, &(&1.payout_hold_reason == "buyer_protection")),
         {:ok, %ProtectionHold{} = hold} <-
           Payments.get_protection_hold_by_payment(payment_id,
             tenant: store_id,
             authorize?: false
           ) do
      ProtectionRelease.release(hold, reason)
    else
      _ -> :ok
    end
  end

  @doc """
  Starts the TC-2 auto-release timer on `order_id`'s buyer-protection hold:
  stamps `release_after` to `ProtectionSweepWorker.release_days()` days from
  now. Called once every one of the order's fulfillments has reached
  `:delivered` — see `Emakola.Orders.Changes.StampProtectionReleaseAfter`,
  hung off `Fulfillment.:mark_delivered`'s after_action hook.

  No-op (returns `:ok`) when: the order was never protected, its hold isn't
  currently `:held`, it's frozen (an open complaint owns the release timing
  instead — see `ProtectionRelease`'s "Freeze respect" for the same
  default elsewhere), or `release_after` is already set. That last check is
  the idempotency guard: a second (or third) fulfillment's delivered
  transition for the same order — or a hook re-running for any other reason
  — never pushes the timer later, since the query only ever matches a hold
  that hasn't started its timer yet.

  Never raises: this hangs off a status-transition hook and must not fail
  the delivered transition on a protection-side hiccup, matching the
  never-fail discipline of `ensure_hold/1` and friends above.

  On a genuine stamp, dispatches `:protection_delivery_nudge` to the buyer
  (TC-2 Task 10). This can run inside the caller's own transaction (the
  `:mark_delivered` hook `Suppliers.InboundFulfillment.verify_delivery/4`
  wraps) — safe because `Dispatcher.dispatch/2` only ever performs an
  `Oban.insert/1` (never `Repo.rollback`), and Oban's Postgres engine is
  configured on the same `Emakola.Repo` (`config :emakola, Oban, repo:
  Emakola.Repo`): inserting from within an ambient Ecto transaction rides
  that same connection/transaction, so the job row commits or rolls back
  atomically with the delivered transition — never visible to the queue
  producer for an uncommitted stamp. Contrast with `ProtectionRelease.release/2,3`,
  which must NEVER run inside a caller's transaction because it calls
  `Repo.rollback` itself (see that module's moduledoc).
  """
  def stamp_release_after_for_order(order_id, store_id) do
    case due_for_timer_start(order_id, store_id) do
      %ProtectionHold{} = hold ->
        release_after =
          DateTime.add(DateTime.utc_now(), ProtectionSweepWorker.release_days(), :day)

        hold
        |> Ash.Changeset.for_update(:set_release_after, %{release_after: release_after})
        |> Ash.update(authorize?: false)
        |> case do
          {:ok, _stamped} ->
            Dispatcher.dispatch(%{id: order_id, store_id: store_id}, :protection_delivery_nudge)
            :ok

          {:error, error} ->
            Logger.error(
              "[protection_holds] stamp_release_after_for_order failed for order=#{order_id}: #{inspect(error)}"
            )

            :ok
        end

      nil ->
        :ok
    end
  rescue
    error ->
      Logger.error(
        "[protection_holds] stamp_release_after_for_order failed for order=#{order_id}: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      :ok
  end

  @doc """
  Sums `net` over `store_id`'s currently `:held` buyer-protection holds — the
  "Held by Buyer Protection" stat tile on the merchant Payouts page (TC-2
  Task 11). A hold that's `:held` but frozen (open complaint) still counts —
  same "frozen is still held" rule as `active_hold_for_order?/2`.
  """
  def held_net_total(store_id) do
    ProtectionHold
    |> Ash.Query.filter(status == :held)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> Enum.reduce(0, &(&1.net + &2))
  end

  @doc """
  Frozen holds — an open buyer complaint (`frozen_at` set; `status` stays
  `:held`, freezing doesn't change it — see the moduledoc) — needing staff
  review. Cross-tenant: no `tenant:` is set (`ProtectionHold` is
  `global?(true)`) so this lists every store's frozen holds, oldest
  complaint first — the platform staff protection queue's first worklist
  (TC-2 Task 12).
  """
  def list_frozen do
    ProtectionHold
    |> Ash.Query.filter(status == :held and not is_nil(frozen_at))
    |> Ash.Query.sort(frozen_at: :asc)
    |> Ash.Query.load([:store, :order])
    |> Ash.read!(authorize?: false)
  end

  @stale_after_days 30

  @doc """
  Stale holds — `:held`, `release_after` never stamped (no
  `Fulfillment.:mark_delivered` has started the auto-release timer — see
  `stamp_release_after_for_order/2`), inserted #{@stale_after_days}+ days
  ago. Nothing else is driving these forward, so they need manual staff
  review — the protection queue's other worklist (TC-2 Task 12), oldest
  first. Cross-tenant, same as `list_frozen/0`.
  """
  def list_stale do
    cutoff = DateTime.add(DateTime.utc_now(), -@stale_after_days, :day)

    ProtectionHold
    |> Ash.Query.filter(status == :held and is_nil(release_after) and inserted_at < ^cutoff)
    |> Ash.Query.sort(inserted_at: :asc)
    |> Ash.Query.load([:store, :order])
    |> Ash.read!(authorize?: false)
  end

  @doc """
  Holds whose delivery nobody but the merchant vouched for — `:held`, with a
  `:delivered` fulfillment that was self-attested rather than confirmed by the
  buyer's code.

  The queue's other two worklists cannot catch these. A self-attested delivery
  is not frozen (there is no complaint) and not stale (the timer DID start), so
  without this it is indistinguishable from a delivery the buyer confirmed.

  Filtered to `:held` on purpose: these are the ones where the money has not
  gone out yet and staff can still act. Once released there is nothing to
  review, only to dispute. Newest first, since the countdown is running.
  Cross-tenant, same as `list_frozen/0`.
  """
  def list_unverified_delivery do
    ProtectionHold
    |> Ash.Query.filter(
      status == :held and
        exists(order.fulfillments, status == :delivered and delivery_verified == false)
    )
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load([:store, :order])
    |> Ash.read!(authorize?: false)
  end

  defp due_for_timer_start(order_id, store_id) do
    ProtectionHold
    |> Ash.Query.filter(
      order_id == ^order_id and status == :held and is_nil(frozen_at) and is_nil(release_after)
    )
    |> Ash.Query.limit(1)
    |> Ash.read!(tenant: store_id, authorize?: false)
    |> List.first()
  end

  # The expected shape of a retried/replayed create hitting the `:unique_payment`
  # identity — a benign no-op, not a failure worth alerting on. Everything else
  # (a genuinely invalid create, an unexpected exception) still logs.
  defp unique_payment_violation?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.InvalidAttribute{field: :payment_id, private_vars: private_vars} ->
        Keyword.get(private_vars, :constraint_type) == :unique

      _ ->
        false
    end)
  end

  defp unique_payment_violation?(_error), do: false

  defp fee_rate_bps do
    Application.get_env(:emakola, :platform_fee_rate_bps, 200)
  end
end
