# Platform Payments & Reconciliation — Design

**Date:** 2026-06-15 · **Status:** Approved, building
**Scope:** First page from the platform-admin expansion roadmap
(`2026-06-15-platform-admin-roadmap.md`). Read-only `/platform/payments`.

## Problem
The platform owner has no view of payment health across stores. GMV is the only
payment-derived metric on the Dashboard. Failures, refunds, and Paystack-vs-Hubtel
reliability are invisible.

## Decision
A **read-only** admin page over the existing `Emakola.Payments.Payment` (no schema
changes), gated by **`:manage_billing`** (reused — sits in the Finance nav section; avoids
permission-catalog churn). Cross-store aggregation relies on `Payment`'s
`multitenancy ... global?(true)` (same mechanism `Platform.Stats.total_gmv/0` already uses);
`Store` is global so `load: [:store]` resolves tenant-lessly. Money is **GHS minor units**
(Payments use Paystack/Hubtel/GHS — unlike Billing's legacy USD).

## Anatomy
1. **Stat strip:** Total payments · Success rate (`success/(success+failed)`) · GMV (Σ amount where success) · Refunds (Σ refunded_amount).
2. **Gateway breakdown:** Paystack vs Hubtel — success count, failed count, success volume.
3. **Failed-payments worklist:** recent `:failed` payments (store, customer_email, amount, gateway, date) — the reconciliation queue. Empty state.
4. **Recent refunds:** recent `:refunded` payments. Empty state.
Conventions: `RequirePermission(:manage_billing)`, disconnected-mount loading shell,
read-only (no events), permission-gated nav link, blue accent, `stat/1`.

## Aggregations (added to `Emakola.Platform.Stats`, mirroring `total_gmv/0`)
`total_payments/0`, `successful_payment_count/0`, `failed_payment_count/0`,
`total_refunded/0`, `payment_gateway_breakdown/0`, `recent_failed_payments/1`,
`recent_refunded_payments/1` — all `authorize?: false`, tenant-less, literal-atom filters.

## Out of scope
Mutations (retry/refund actions flow through gateways/webhooks), per-store payment detail,
charts/time-series (that arrives with the Analytics page + charts capability).

## Success criteria
`/platform/payments` loads for `:manage_billing` staff (others bounced to `/platform`);
shows real success rate / gateway split / failed worklist / refunds with empty states;
`mix test` green incl. a two-store cross-tenant Stats test; format + credo clean.
