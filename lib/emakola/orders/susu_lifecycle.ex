defmodule Emakola.Orders.SusuLifecycle do
  @moduledoc """
  The one convergent end-of-life path every susu plan goes through (TC-3
  Task 6). Buyer cancel (Task 7's signed page), merchant cancel (Task 9's
  admin), platform takedown, and deadline expiry (both the latter via
  `Emakola.Payments.Workers.SusuExpiryWorker`'s hourly sweep) all reduce to
  one of the two public functions here, and both funnel through the exact
  same three steps: transition the plan, release any reserved stock,
  initiate refunds for every counted contribution.

  ## Zero-contribution plans

  A plan cancelled while still `:pending` (a susu link the merchant
  cancels before any buyer has paid a first chunk) has never reserved
  stock — `SusuStock.reserve/1` only runs at ACTIVATION, the first
  confirmed chunk (see `SusuChunks.confirm_chunk/1`) — and has no counted
  contributions to refund. `SusuStock.release/1` and
  `SusuRefunds.refund_all_contributions/1` are both no-ops in that case by
  construction (`release/1` reads the plan's own `stock_reserved` flag;
  `refund_all_contributions/1` finds no counted payments), so calling them
  unconditionally below is correct, not wasted work — a clean transition,
  no refunds, no stock movement.

  ## Task 8 seam

  The spec calls for notifying both sides on every end-of-life transition
  ("product taken down mid-plan → auto-cancel + full refund + notify
  both") — that's Task 8's job: susu-specific `Dispatcher` events
  (`:susu_refunded`, `:susu_merchant_expired`, etc.) don't exist yet (see
  the feature plan's Task 8 section). Nothing here calls a notifier by
  design — Task 8 adds its dispatch call(s) at the marked point in both
  functions below, AFTER refunds have been initiated, mirroring
  `SusuCompletion.complete/1`'s "dispatch only once the real work has
  happened, never speculatively" discipline.
  """

  require Logger

  alias Emakola.Orders.SusuPlan
  alias Emakola.Orders.SusuStock
  alias Emakola.Payments.SusuRefunds

  @doc """
  Cancels `plan`. `by` (`:buyer | :merchant | :takedown`) identifies who
  initiated the cancellation — recorded for logging only today; Task 8's
  notification wiring is expected to use it to choose buyer- vs.
  merchant-facing copy (see moduledoc's Task 8 seam).

  Only a `:pending` or `:active` plan can be cancelled
  (`SusuPlan.:cancel`'s own status guard, enforced by
  `Emakola.Orders.cancel_susu_plan!/2`) — calling this on an
  already-terminal plan raises, same as any other Ash update whose
  validation fails.
  """
  def cancel(%SusuPlan{} = plan, by) when by in [:buyer, :merchant, :takedown] do
    cancelled = Emakola.Orders.cancel_susu_plan!(plan, authorize?: false)
    converge(cancelled)

    Logger.info("[susu_lifecycle] plan=#{plan.id} cancelled by=#{by}")

    # Task 8 seam: dispatch the buyer refund-confirmation event and the
    # merchant cancellation event here, once susu Dispatcher events exist.

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

    # Task 8 seam: dispatch the buyer refund-confirmation event and the
    # merchant expiry event here, mirroring cancel/2 above.

    {:ok, expired}
  end

  defp converge(plan) do
    SusuStock.release(plan)
    SusuRefunds.refund_all_contributions(plan)
  end
end
