# Refund Oversight — Design

## Context

Third of the three remaining platform-admin features. Exploration: **refunds ARE
captured** — `Payment.status` has `:refunded` + a `refunded_amount` field +
`mark_refunded` action (and the Order `Return` resource has a `:refunded` status). But
**disputes/chargebacks are NOT modeled** (no Dispute resource, no gateway dispute
webhooks). So v1 = **refund oversight on real data**; dispute oversight is deferred
(needs a Dispute resource + Paystack/Hubtel dispute webhooks — a separate feature).

Built in the **Makola Admin design language** (`[[emakola-admin-ui-standard]]`).
Branch: `feature/refund-oversight`. TDD throughout.

## Data (no new resource — surface existing `Payment`)

`Payment` is `global?(true)` multitenant, so platform code reads across all stores with
`authorize?: false`. Add:
- `Payment` read **`:list_refunded`** — `filter status == :refunded`, sort `inserted_at`
  desc, default limit 100, `prepare build(load: [:store])`. Interface `list_refunded_payments`.
- `Emakola.Platform.Stats` (existing aggregates module): **`total_refunded/0`**
  (`Ash.sum(:refunded_amount)` where `status == :refunded`) and **`refund_count/0`**
  (`Ash.count` where `status == :refunded`) — mirroring `total_gmv/0`.

Money is integer minor units (pesewas); format only in the view.

## Page — `/platform/refunds` (`RefundsLive`)

Gated by **`:manage_billing`** (financial). Loading-shell (Iron Law #1);
`Stats.total_refunded/0` + `refund_count/0` + `Payments.list_refunded_payments/0` on
connected mount. Elevated UI:
- **Hero stat tiles**: Total refunded (formatted money) · Refunds (count) · (room for refund-rate later).
- **Refunds table**: store, original amount, refunded amount, gateway, date — money formatted, severity-neutral.
- **Empty state**: friendly icon + "No refunds yet" copy.
- Nav link "Refunds" under Finance (after Payments), gated `:manage_billing`.

## Build sequence (tests → impl → green)

1. `Payment :list_refunded` + `Stats.total_refunded/0`/`refund_count/0` → tests: a
   created→success→refunded payment appears in `list_refunded_payments`; totals sum/count
   correctly; non-refunded excluded. (Build refunded payments via `create_payment!` →
   `mark_success` → `mark_refunded`.)
2. `RefundsLive` + route + nav (elevated UI) → LiveView tests: renders tiles + a refunded
   row; `:manage_billing` gating; empty state.
3. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, new test
   files clean under `--warnings-as-errors`. PR + CI.

## Out of scope (v1)

Dispute/chargeback oversight (unmodeled — separate feature); refund *initiation* from the
platform (read-only here); per-store refund-rate trends; CSV export; refunds via the Order
`Return` flow surfaced separately (the `Payment` is the money source of truth).
