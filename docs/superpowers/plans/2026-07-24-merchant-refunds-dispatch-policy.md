# Merchant Refunds + Dispatch-Fee Policy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make merchant-initiated refunds real end to end, and protect a dispatched supplier's dispatch fee from clawback unless the merchant marks the supplier at fault.

**Architecture:** Customer return requests persist; approving a return calls a new `Emakola.Payments.RefundService` which initiates the gateway refund; the existing `refund.processed` webhook stays the only writer of ledger state, and `RefundLiability.reconcile!/2` gains a per-split "reversible base" carve-out implementing the dispatch-fee policy. Spec: `docs/superpowers/specs/2026-07-24-merchant-refunds-dispatch-policy-design.md`.

**Tech Stack:** Elixir, Ash 3.x, Phoenix LiveView, Oban, Mox, ExUnit.

## Global Constraints

- TDD, no exceptions: failing test first, watch it fail for the right reason, then implement.
- ALL commands FOREGROUND — never background, never wait on notifications. Parse the "Result:" line; the exit code lies.
- **Money is integer pesewas.** Never floats in the ledger. `format_price/1` drops decimals on round-hundred pesewas — never assert `"45.00"` literals in tests.
- **Invariant, non-negotiable:** after `reconcile!/2`, `Σ (reversals recorded across splits) == proportional_amount(payment.amount, payment.refunded_amount, payment.amount) == payment.refunded_amount`. Every new test path asserts it.
- Split roles are `:wholesaler | :dropshipper | :platform | :merchant | :credit_partner`. Dispatched statuses are `:shipped | :delivered`; not-dispatched are `:pending | :notified | :cancelled`.
- `protected_fee = min(fulfillment.dispatch_fee, split.amount)`.
- Fallbacks behave EXACTLY as today (bases equal amounts): nil `payment.order_id`, no fulfillments, all fees zero, no `:dropshipper` split, or the order's Return has `refund_dispatch_fee?` true.
- The `RefundService` never writes `payment.refunded_amount` — the webhook is the single writer.
- No `authorize?: false` writes in the web layer; services take an actor.
- `mix format`; `mix credo --strict` on touched lib files; `MIX_ENV=test mix compile --warnings-as-errors` (touch edited files first); conventional commits.

---

### Task 1: Persist customer return requests

**Files:**
- Modify: `lib/emakola_web/live/storefront/account_live.ex:108-130` (`submit_return_request`)
- Test: `test/emakola_web/live/storefront/account_live_test.exs`

**Interfaces:**
- Consumes: `Emakola.Orders.request_return/2` (exists, `orders.ex`; create action `:request_return` accepts `:store_id, :order_id, :customer_id, :reason, :reason_detail, :currency` — `return.ex:131`).
- Produces: a persisted `Return` in `:requested` status that Task 4's merchant flow can approve.

**Steps:** (1) Failing test: submitting the return modal for an order creates exactly one `Return` row for that order with the chosen reason, and re-submitting for the same order does not raise (unique identity on `order_id` — surface a friendly flash instead). (2) Watch it fail (today nothing is persisted). (3) Implement: call `Emakola.Orders.request_return/2` with the order's `store_id`, `order_id`, `customer_id`, the `SafeAtom`-guarded reason, and the order currency; keep the existing assigns update so the UI still reflects state; on `{:error, _}` flash "We couldn't submit that return request." (4) Focused suite green. (5) Commit `feat(orders): customer return requests persist`.

---

### Task 2: `refund_dispatch_fee?` on Return

**Files:**
- Modify: `lib/emakola/orders/resources/return.ex` (attribute near `:69`; add to `:approve`'s `accept` at `:144`)
- Create: migration via `mix ash.codegen add_return_refund_dispatch_fee`
- Test: `test/emakola/orders/return_test.exs` (create it if absent)

**Steps:** (1) Failing test: `approve_return` accepts `refund_dispatch_fee?: true` and persists it; default is `false`. (2) Watch fail. (3) Add `attribute :refund_dispatch_fee?, :boolean do allow_nil?(false); default(false); public?(true) end` and extend `accept([:admin_notes, :refund_amount, :refund_dispatch_fee?])`. (4) `mix ash.codegen add_return_refund_dispatch_fee` then `mix ecto.migrate`. **Gotcha:** codegen writes FK/index lines that fail CI's formatter — run `mix format` on the generated migration and split any `references(...), null: false` one-liner. (5) Green + commit `feat(orders): returns record the supplier-at-fault refund choice`.

---

### Task 3: Dispatch-fee protection in `RefundLiability.reconcile!/2`

This is the money math. Treat every edge as a correctness bug, not a style question.

**Files:**
- Modify: `lib/emakola/payments/refund_liability.ex` (`reconcile!/2` + new private helpers)
- Test: `test/emakola/payments/refund_liability_test.exs`

**Interfaces:**
- Consumes: `Emakola.Orders.Fulfillment` (`order_id`, `supplier_id`, `status`, `dispatch_fee`), `Emakola.Orders.get_return_by_order/2` (`orders.ex:54`), `PaymentSplit.supplier_id`.
- Produces: `reconcile!/2` keeps its `(payment, splits) :: :ok` signature — callers unchanged.

**Steps:**

(1) Write the failing tests FIRST. Cover, each asserting the sum invariant:
  - full refund, one wholesaler `:shipped` → that wholesaler's reversal is `amount - dispatch_fee`; the dropshipper's reversal is its own amount `+ dispatch_fee`.
  - same but `:pending` → today's proportional numbers, unchanged.
  - mixed: two wholesalers, one `:delivered` one `:notified` → only the delivered one is protected.
  - partial refund (e.g. 40%) with protection → invariant holds, protection scales through the base.
  - cumulative partials (30% then another 30%) → reversals are cumulative-quota differences, never double-counted.
  - Return with `refund_dispatch_fee?: true` → protection waived, numbers identical to the unprotected case.
  - fallbacks, each asserting byte-identical behavior to today: `payment.order_id` nil; no fulfillments; `dispatch_fee` all zero; no `:dropshipper` split present.
  - `dispatch_fee > split.amount` → clamped by `min/2`, no negative base.

(2) Run them; watch them fail for the right reason (protection not applied).

(3) Implement. Keep the existing cumulative-quota reduce exactly as it is, but fold over a precomputed list of `{split, base}` instead of `split`:

```elixir
  def reconcile!(payment, splits) do
    splits
    |> Enum.sort_by(& &1.id)
    |> with_reversible_bases(payment)
    |> Enum.reduce({0, 0}, fn {split, base}, {base_before, target_before} ->
      base_after = base_before + base

      target_after =
        proportional_amount(base_after, payment.refunded_amount, payment.amount)

      reversed_amount = target_after - target_before

      if reversed_amount > split.reversed_amount do
        split
        |> Ash.Changeset.for_update(:record_reversal, %{reversed_amount: reversed_amount})
        |> Ash.update!(authorize?: false)
      end

      {base_after, target_after}
    end)

    :ok
  end
```

`with_reversible_bases/2` returns `[{split, base}]` in the same order, where the
protected fees are subtracted from their wholesaler splits and the total is
added to the single `:dropshipper` split. It must return
`Enum.map(splits, &{&1, &1.amount})` unchanged whenever any fallback applies —
write the guard clauses first, before the interesting path. Assert in a test
that `Σ base == payment.amount` for every scenario; that equality is what keeps
the invariant true.

Protection set = for each `:wholesaler` split, the fulfillment matching
`payment.order_id` + `split.supplier_id` whose status is `:shipped` or
`:delivered`, when the order's Return does not have `refund_dispatch_fee?` true.
Load fulfillments once per call (one query, not per split) and the Return once.

(4) Tests green. (5) `mix credo --strict` on the file. (6) Commit `feat(payments): dispatched supplier dispatch fees survive refunds`.

---

### Task 4: `RefundService.issue/3` + wire the approve path

**Files:**
- Create: `lib/emakola/payments/refund_service.ex`
- Modify: `lib/emakola_web/live/admin/return_live.ex:83-108` (`approve_return` event)
- Test: `test/emakola/payments/refund_service_test.exs`, `test/emakola_web/live/admin/return_live_test.exs`

**Interfaces:**
- Consumes: `Emakola.Payments.Gateway.process_refund/2` (behaviour at `gateway.ex:9`; Mox-mocked in tests), `Emakola.Orders.approve_return/3`.
- Produces: `RefundService.issue(actor, return, %{refund_amount: pesewas, admin_notes: String.t(), refund_dispatch_fee?: boolean()}) :: {:ok, Return.t()} | {:error, term()}`.

**Steps:** (1) Failing service tests with the Mox gateway: happy path calls `process_refund/2` once with the payment's gateway reference and the pesewa amount, and approves the Return with all three fields; an amount exceeding `payment.amount - payment.refunded_amount` returns `{:error, :amount_exceeds_refundable}` and calls the gateway ZERO times; a payment whose gateway returns `{:error, :not_supported}` returns `{:error, :gateway_unsupported}` and leaves the Return in `:requested`; an order with no payment returns `{:error, :payment_not_found}`. Assert in every failure case that `payment.refunded_amount` is untouched (the webhook is the only writer). (2) Watch fail. (3) Implement the service — order → payment lookup, validation, gateway call, then `approve_return` only after the gateway accepts. (4) LiveView test: approving with the toggle checked passes `refund_dispatch_fee?: true` through; the unsupported-gateway error renders "Refunds for this payment must be issued in the provider dashboard." (5) Rewrite the LV handler to call the service (keep the existing flash-on-success behavior; parse the amount with `Emakola.Money.parse_price/1` rather than `Float.parse` — the current code silently yields `nil` on bad input). (6) Both suites green. (7) Commit `feat(payments): merchants issue refunds from the returns page`.

---

### Task 5: Refund guidance UI

**Files:**
- Modify: `lib/emakola_web/live/admin/return_live.ex` (approve modal region ~`:320-340` and its assigns at `:40`/`:64`)
- Test: `test/emakola_web/live/admin/return_live_test.exs`

**Steps:** (1) Failing tests: the panel shows the refundable balance; each supplier's dispatch fee appears with its dispatch state; the at-fault toggle renders ONLY when at least one fulfillment is `:shipped`/`:delivered`; typing an amount above `refundable - protected fees` renders a warning (soft — the approve button stays enabled). (2) Watch fail. (3) Implement with the Makola Admin design language (load the frontend-design skill): stat-style figures, severity pill for dispatch state, no new CSS. Mobile: verify at 375px, single column, no horizontal scroll. (4) Green. (5) Full gates FOREGROUND: `mix format --check-formatted`; `mix credo --strict` on touched lib files; `MIX_ENV=test mix compile --warnings-as-errors`; FULL `mix test`. (6) Commit `feat(web): refund panel shows dispatch-fee exposure`. Do NOT push — the controller runs visual verification and the whole-branch review first.
