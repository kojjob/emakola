# Platform Admin — Expansion Roadmap

**Date:** 2026-06-15
**Status:** Brainstorm output / living roadmap (owner: Kojo)
**Context:** The platform-admin redesign shipped Settings, Merchants, and Billing
(PRs #142/#144/#146). The owner area is still thin: the Dashboard is 7 point-in-time
counts + a recent-stores table, there are no time-series/charts, no proactive alerts,
the top-bar search is dead, and `Stores` is metadata-only. Meanwhile a lot of real data
across domains is unsurfaced. This roadmap captures what to add next, grounded in data
that already exists (no schema changes unless noted).

## Conventions every new page follows
Established across Settings/Merchants/Billing (see those specs): live in `:platform`
live_session; `on_mount {RequirePermission, :perm}`; disconnected-mount loading shell;
read-only ⇒ no per-event re-auth (mutating pages re-auth every write); permission-gated
sidebar link; tests via `Emakola.LiveViewHelpers.setup_platform_staff`; blue accent,
`rounded-xl` cards, local `stat/1`. Cross-store reads use `authorize?: false` and rely on
each resource's multitenancy (`Payment` has `global?(true)`; `Store`/`Organisation` are
global) — mirror `Emakola.Platform.Stats.total_gmv/0`.

## New pages (priority order — owner-selected, all chosen)

1. **Payments & Reconciliation** `/platform/payments` — **BUILDING FIRST** (own spec+plan
   `2026-06-15-platform-payments*`). Payment success rate, gateway split (Paystack/Hubtel),
   refunds, failed-payments worklist. Gated `:manage_billing`. Data: `Payments.Payment`.
2. **Analytics / Revenue** `/platform/analytics` — GMV & order trends over time, AOV, top
   stores/products, gateway revenue split. **Marquee page; requires the time-range +
   charts capability first.** Data: Orders, Payments, Stores (`view_count`). New read
   actions for period aggregation.
3. **Suppliers / Dropshipping** `/platform/suppliers` — supplier directory, fulfillment
   success rate + days-to-ship (`Fulfillment.supplier_id`/`status`/timestamps), settlement
   aging / payouts owed (`SupplierLedgerEntry.status`/`amount_owed`, `Supplier.outstanding_balance`).
   Likely `:manage_stores` or a new `:manage_suppliers`.
4. **Customers & Catalog quality** `/platform/customers` (+ catalog tab/section) — customer
   growth, CLV distribution (`Customer.total_spent`), repeat rate (`order_count`), churn
   (`last_order_at`); product mix by `product_type`, dead products (`variant_count==0`),
   review moderation/authenticity (`Review.verified_purchase`/`status`/`rating`).
5. **Contacts & Messages** `/platform/messages` — **notification/message log** (owner's
   chosen meaning): what was SENT to customers — `Notifications.EmailLog`
   (status/template/bounces) + WhatsApp/SMS fulfillment notifications
   (`Fulfillment.notified_via`/`notified_at`). Deliverability + history. NOT a support inbox
   (no messaging model exists). Likely any-staff or `:manage_settings`.

## Cross-cutting capabilities (owner-selected, all)

- **Time-range + trend charts** — a shared date-range selector + a charting approach (pick a
  lib or lightweight SVG/`contex`; decide in the Analytics spec). Foundational for Analytics.
- **Alerts strip on Dashboard** — a "needs attention" band: failed payments, past-due
  subscriptions, low stock, overdue supplier settlements. Reuses the per-page Stats.
- **Store / Merchant performance drill-downs** — `Stores` is metadata-only and the Merchants
  drawer is profile-only; add revenue/orders/products/customers detail. (Merchants drawer
  already exists — extend it; add a Store show/drawer.)
- **Export + global search** — CSV export on tables; wire the dead top-bar ⌘K search across
  stores/merchants/orders (a `Platform.Search` aggregator).

## Suggested sequencing
Payments (now) → Alerts strip on Dashboard (cheap, reuses Stats) → Analytics + charts
capability (marquee, unlocks trends) → Suppliers → Customers/Catalog → Messages →
drill-downs + export/search woven in as each page lands.

## Notes / open decisions
- **Permissions:** the catalog (`platform_permissions.ex`) has stores/merchants/team/audit/
  billing/settings. New finance-ish pages reuse `:manage_billing`; Suppliers may want a new
  `:manage_suppliers`. Add permissions sparingly (each touches the catalog + team UI + tests).
- **Charts:** no charting lib is in `mix.exs` today — the Analytics spec must choose one
  (decision deferred to that sub-project).
- **Billing caveat carries over:** the Billing domain is legacy Stripe/org/USD; Analytics
  revenue should use **Payments GMV (Paystack/Hubtel, GHS)**, not Billing invoices.
