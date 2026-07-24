# Merchant-Initiated Refunds + Dispatch-Fee Policy — Design

**Date:** 2026-07-24
**Status:** Approved (scope + policy locked with Kojo)

## Why

Today a merchant **cannot refund a customer from Makola at all**. Approving a
return (`return.ex:142-161`) records an amount and nothing else — no gateway
call, no ledger movement. Real refunds happen only when someone issues them in
the Paystack dashboard; `refund.processed` then arrives at
`paystack_webhook_handler.ex:268` and splits reverse strictly proportionally.
Customer return requests are never even persisted (`account_live.ex:108-130`
mutates assigns only). That is a launch blocker once real payment keys go in.

This project makes refunds real end to end, and defines what happens to the
supplier dispatch fee — the first post-checkout reader of
`Fulfillment.dispatch_fee`, which until now is a write-only snapshot.

## Policy (locked)

Per supplier fulfillment on the order:

- **Not dispatched** (`:pending`, `:notified`, `:cancelled`): the dispatch fee
  is refundable like any allocation — clawed back from the supplier, who has
  not spent courier money.
- **Dispatched** (`:shipped`, `:delivered`): the fee is **protected** — the
  supplier keeps it, and the refunding merchant's own split absorbs that
  portion of the reversal.
- **Merchant override**: approving a return may set "Supplier at fault —
  include dispatch fee", which waives protection for that order so fees claw
  back normally. Default off. Persisted on the `Return` (the reversal happens
  asynchronously in the webhook, so the decision cannot live in LiveView
  state) and therefore auditable.

## Ledger mechanics

`SplitCalculator` folds each dispatch fee into that wholesaler's allocation
(`split_calculator.ex:89`), so protection cannot be expressed by adjusting
`refunded_amount` — it needs a per-split carve-out. `RefundLiability.reconcile!/2`
gains a **reversible base** per split, then runs its existing cumulative-quota
algorithm over the base instead of the raw amount:

- protected `:wholesaler` split → `base = amount - protected_fee`
- the `:dropshipper` split → `base = amount + Σ protected_fee` (absorbs)
- every other split → `base = amount`

`Σ base == payment.amount` by construction, so `Σ reversals` still equals the
refunded amount exactly — the invariant `reconcile!` already guarantees.

`protected_fee = min(fulfillment.dispatch_fee, split.amount)`.

A dropshipper reversal may exceed that split's own amount; this is intended
(the merchant owes it) and already representable: `reversed_amount` has no
upper bound and `record_reversal` marks the split `:reversed` once the
reversal meets the amount. The existing recovery machinery
(`RefundLiability.reserve!`) claws the excess from the merchant's future
earnings.

**Fallbacks — never break the invariant.** If `payment.order_id` is nil
(group-buy commitments, preorder deposits), if no fulfillments exist, if no
dispatch fees are non-zero, or if there is no `:dropshipper` split to absorb,
reconcile behaves exactly as it does today (bases equal amounts).

## Flow

1. **Customer requests a return** (storefront account page) — now actually
   persists via `Emakola.Orders.request_return/2` instead of mutating assigns.
2. **Merchant approves** in the admin returns page with an amount and the
   optional at-fault toggle. The approve path now calls a new
   `Emakola.Payments.RefundService.issue/3`, which finds the order's payment,
   validates the amount against the refundable balance
   (`payment.amount - payment.refunded_amount`), and calls
   `gateway.process_refund/2`.
3. **Gateway confirms asynchronously.** The existing `refund.processed`
   webhook remains the single place that moves the ledger: it marks the
   payment refunded (cumulative) and calls `reconcile!`, which now applies the
   dispatch-fee policy. The service never writes `refunded_amount` itself —
   one writer, no double-counting.

Hubtel's gateway returns `{:error, :not_supported}`; the UI surfaces
"Refunds for this payment must be issued in the provider dashboard" rather
than failing opaquely.

## UI (admin returns page)

The approve panel gains: the refundable balance, each supplier's dispatch fee
with its dispatch state, the at-fault toggle (hidden when nothing on the order
is dispatched), and a soft warning when the typed amount exceeds
`refundable balance - protected fees`. No hard block — merchants may
deliberately refund more and absorb it.

## Testing

- Money math is probe-verified the way PR #344's split math was: property-ish
  tests asserting `Σ reversals == refunded_amount` across protected /
  unprotected / mixed / full / partial / cumulative-partial cases.
- Each fallback (nil `order_id`, no fulfillments, zero fees, absent
  dropshipper split) asserts byte-identical behavior to today.
- Service tests use the Mox payment gateway; never a real API.
- LiveView tests: toggle renders only when something is dispatched, warning
  appears past the suggested max, unsupported-gateway error surfaces.

## Out of scope

Supplier notification when a fee is clawed back (platform audit covers it for
now); platform dispute tooling; per-line-item partial-return math (returns
stay order-level); refunds for group-buy/preorder payments (they already have
their own paths).
