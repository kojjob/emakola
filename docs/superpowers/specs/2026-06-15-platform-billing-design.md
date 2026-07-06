# Platform Billing — Read-only Admin View

**Date:** 2026-06-15
**Status:** Approved design, pending implementation plan
**Scope:** Sub-project 3 of 3 in the platform-admin redesign (Settings ✅ → Merchants ✅ → **Billing**).

## Problem

The platform sidebar has a disabled "Soon" **Billing** stub. A full `Emakola.Billing`
domain already exists (Plan, Subscription, Invoice, UsageRecord + Stripe workers) but has
**no admin UI**. The project owner needs a read-only window into it.

**Decision (owner, 2026-06-15):** build `/platform/billing` as a **read-only admin view
over the existing Billing domain as-is**. No model changes, no new billing logic.

> **Caveat (documented, not fixed here):** the existing Billing domain is **FounderPad
> legacy** — it bills `Organisation`s via **Stripe** in **USD cents**, with plan limits
> framed as seats/agents/API calls. This does NOT match Emakola's merchant/store +
> Paystack + GHS commerce model. The page surfaces this domain faithfully (USD, orgs);
> reconciling Emakola's *real* merchant billing is explicitly **out of scope** and a
> future initiative. Data may be sparse today — empty states cover that.

## Background — existing domain (no changes)

`Emakola.Billing` interfaces: `list_plans`, `list_subscriptions`, `list_invoices`
(+ get/create variants). All reads are usable with `authorize?: false`.

- **Plan**: `name`, `slug`, `price_cents` (USD cents), `interval` (`:monthly`/`:yearly`),
  `features` ([string]), `max_seats`, `max_agents`, `max_api_calls_per_month`, `active`,
  `sort_order`.
- **Subscription**: `status` (`:active|:past_due|:canceled|:incomplete|:trialing|:unpaid`),
  `current_period_start/end`, `cancel_at_period_end`, `trial_end`; `belongs_to`
  `:organisation` + `:plan`.
- **Invoice**: `invoice_number`, `amount_cents`, `status` (atom), `period_start/end`
  (dates); `belongs_to :organisation`.

`Organisation` has `name`. Factories exist: `create_plan!/1`, `create_invoice!/2`; a
`create_subscription!/3` helper will be added (Task 1).

## 1. Routing & navigation

**Router** (`router.ex`) — inside the existing `:platform` live_session:
```elixir
live "/platform/billing", Platform.BillingLive
```
**Layout** — replace the disabled Billing "Soon" stub with a permission-gated link
(mirrors Stores/Merchants/Settings):
```heex
<.sidebar_link
  :if={Emakola.Accounts.PlatformPermissions.allowed?(@current_user, :manage_billing)}
  href="/platform/billing"
  title="Billing"
  icon="currency"
  active={@active_nav == :billing}
/>
```

## 2. LiveView — `EmakolaWeb.Platform.BillingLive`

File: `lib/emakola_web/live/platform/billing_live.ex`. Read-only (no mutating events ⇒
no per-event re-auth). Mirrors the conventions proven on Stores/Merchants/Settings.

- `on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}`.
- **Disconnected-mount loading shell**: in `mount`, only query when `connected?(socket)`;
  otherwise assign a nil state and render a "Loading…" shell (no DB).
- Assigns when loaded: `:plans`, `:subscriptions` (loaded `[:organisation, :plan]`),
  `:invoices` (loaded `[:organisation]`), `:stats`.
- All reads `authorize?: false`, wrapped in a `rescue` returning `[]` (like `StoreLive`).
- No events (the page is static once loaded). `:active_nav` → `:billing`.

### Stats (derived)
- `mrr_cents` = Σ over **active** subscriptions of monthly-normalized plan price
  (`:monthly` → `price_cents`; `:yearly` → `div(price_cents, 12)`).
- `active_subscriptions` = count status `:active`.
- `active_plans` = count `plan.active`.
- `needs_attention` = count subscriptions with status in `[:past_due, :unpaid]`.

## 3. UI anatomy

Container `<div class="p-6 lg:p-8 max-w-7xl mx-auto">`, blue accent.

1. **Header** — "Billing" + subtitle. A small muted note: "Amounts in USD (Stripe billing)."
2. **Stat strip** — 4 cards (reuse the local `stat/1` style): MRR (`format_usd`),
   Active subscriptions, Active plans, Needs attention.
3. **Plans** — section card with a table: Plan (name + slug), Price (`$X.XX/mo|/yr`),
   Limits (seats/agents/API), Status (Active/Inactive). Sorted by `sort_order`.
   Empty state: "No plans configured."
4. **Subscriptions** — table: Organisation (`sub.organisation.name`), Plan
   (`sub.plan.name`), Status badge (color per status: active=green, trialing=blue,
   past_due/unpaid=amber, canceled/incomplete=slate), Renews (`current_period_end`).
   Empty state: "No subscriptions yet."
5. **Recent invoices** — table (most recent ~10): Invoice # , Organisation, Amount
   (`format_usd`), Status badge, Period. Empty state: "No invoices yet."

`format_usd(cents)` → `"$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"` (helper).

Status-badge color is a small `defp` mapping atom → tailwind classes.

## 4. Testing (TDD — first)

`test/emakola_web/live/platform/billing_live_test.exs`, using `Emakola.LiveViewHelpers`.

1. **Permission gating**: owner mounts; staff with `:manage_billing` mounts; staff with
   `[:manage_team]` bounced to `/platform`.
2. **Disconnected mount** renders a loading shell without hitting the DB (`get/2` then
   `html_response(conn, 200)` =~ "Loading", refute a seeded plan name).
3. **Renders** seeded plan name, subscription's org + plan, and an invoice number.
4. **Stat strip** shows labels + a non-zero MRR for one active monthly subscription.
5. **Empty state** when no billing data.

Add **`Factory.create_subscription!/3`** (org, plan, attrs) in Task 1 — accepts
`organisation_id`/`plan_id` args + stripe ids + status; `current_period_*` are
`:utc_datetime` so truncate `DateTime.utc_now()` to `:second`.

## 5. Out of scope
- Any billing mutation (create/cancel subscriptions, edit plans, issue invoices) — those
  flow through Stripe webhooks/workers, not this admin view.
- Reconciling the legacy Stripe/org/USD model with Emakola's merchant/Paystack/GHS model.
- UsageRecord display (not needed for the owner overview now).

## Success criteria
- `/platform/billing` loads for staff with `:manage_billing` (no 404; "Soon" stub gone),
  shows plans/subscriptions/invoices + MRR from the real domain, with empty states when sparse.
- `mix test` green incl. new file; `mix format --check-formatted` + `mix credo --strict` clean.
- Visual language matches the platform shell and the Settings/Merchants pages.
