defmodule Emakola.Orders.SusuLifecycle do
  @moduledoc """
  The one convergent end-of-life path every susu plan goes through (TC-3
  Task 6). Buyer cancel (Task 7's signed page), merchant cancel (Task 9's
  admin), platform takedown, deadline expiry (both the latter via
  `Emakola.Payments.Workers.SusuExpiryWorker`'s hourly sweep), and a
  system-initiated cancel (`SusuChunks.confirm_chunk/1`'s insufficient-stock
  path) all reduce to one of the two public functions here, and both funnel
  through the exact same three steps: transition the plan, release any
  reserved stock, initiate refunds for every `:success` payment on the plan.

  ## Zero-contribution plans

  A plan cancelled while still `:pending` (a susu link the merchant
  cancels before any buyer has paid a first chunk) has never reserved
  stock — `SusuStock.reserve/1` only runs at ACTIVATION, the first
  confirmed chunk (see `SusuChunks.confirm_chunk/1`) — and has no
  successful payments to refund. `SusuStock.release/1` and
  `SusuRefunds.refund_all_contributions/1` are both no-ops in that case by
  construction (`release/1` reads the plan's own `stock_reserved` flag;
  `refund_all_contributions/1` finds no `:success` payments), so calling
  them unconditionally below is correct, not wasted work — a clean
  transition, no refunds, no stock movement.

  ## Task 8: notifying both sides

  The spec calls for notifying both sides on every end-of-life transition
  ("product taken down mid-plan → auto-cancel + full refund + notify
  both"). Both `cancel/2` and `expire/1` dispatch `:susu_refunded` (buyer)
  and `:susu_merchant_expired` (merchant) AFTER refunds have been
  initiated (`converge/1`), mirroring `SusuCompletion.complete/1`'s
  "dispatch only once the real work has happened, never speculatively"
  discipline. Both events are plan-based (`Dispatcher.dispatch_susu/2`) —
  no order exists at this point (see `Dispatcher`'s "Susu coupling"
  moduledoc section).

  There is only one merchant terminal event
  (`:susu_merchant_expired`) — it fires for every non-completion
  end-of-life regardless of `by` (buyer cancel, merchant cancel, or
  takedown auto-cancel), not just a genuine deadline expiry. The `by`
  argument only affects the log line today; a `:pending`, never-activated
  plan has no customer/contact to notify anyway (both events short-circuit
  cleanly in `SusuNotificationWorker` when there's no customer/phone —
  same as `OrderNotificationWorker`'s existing posture).
  """

  require Logger

  alias Emakola.Notifications.Dispatcher
  alias Emakola.Orders.SusuPlan
  alias Emakola.Orders.SusuStock
  alias Emakola.Payments.SusuRefunds

  @doc """
  Cancels `plan`. `by` (`:buyer | :merchant | :takedown | :system`)
  identifies who initiated the cancellation — recorded for logging only;
  see moduledoc's "Task 8: notifying both sides" section for why it does
  not otherwise change the notification sent. `:system` is
  `SusuChunks.confirm_chunk/1`'s insufficient-stock path — the plan's own
  stock check failing, not any person's action.

  Only a `:pending` or `:active` plan can be cancelled
  (`SusuPlan.:cancel`'s own status guard, enforced by
  `Emakola.Orders.cancel_susu_plan!/2`) — calling this on an
  already-terminal plan raises, same as any other Ash update whose
  validation fails.
  """
  def cancel(%SusuPlan{} = plan, by) when by in [:buyer, :merchant, :takedown, :system] do
    cancelled = Emakola.Orders.cancel_susu_plan!(plan, authorize?: false)
    converge(cancelled)

    Logger.info("[susu_lifecycle] plan=#{plan.id} cancelled by=#{by}")

    dispatch_end_of_life(cancelled)

    {:ok, cancelled}
  end

  @doc """
  Expires `plan` — `SusuExpiryWorker`'s deadline-passed branch, the other
  caller of the same convergent path `cancel/2` uses.
  """
  def expire(%SusuPlan{} = plan) do
    expired = Emakola.Orders.expire_susu_plan!(plan, authorize?: false)
    converge(expired)

    Logger.info("[susu_lifecycle] plan=#{plan.id} expired")

    dispatch_end_of_life(expired)

    {:ok, expired}
  end

  defp converge(plan) do
    SusuStock.release(plan)
    SusuRefunds.refund_all_contributions(plan)
  end

  defp dispatch_end_of_life(plan) do
    dispatch_susu_event(plan, :susu_refunded)
    dispatch_susu_event(plan, :susu_merchant_expired)
  end

  defp dispatch_susu_event(plan, event) do
    case Dispatcher.dispatch_susu(plan, event) do
      {:ok, _job} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[susu_lifecycle] #{inspect(event)} dispatch failed: #{inspect(reason)}",
          plan_id: plan.id
        )
    end
  end
end
