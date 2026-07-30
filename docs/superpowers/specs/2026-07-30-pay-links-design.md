# Pay Links — Design

**Date:** 2026-07-30
**Status:** Approved (brainstorm with Kojo, 2026-07-30)
**Spec 1 of 4** in the Ghana trust-commerce series: Pay Links → Buyer Protection → Susu lay-away → GhanaPost GPS addressing.

## Purpose

IG/WhatsApp social sellers — the target segment of the revenue-first strategy
(`docs/REVENUE-FIRST-90-DAY-PLAN.md`) — close deals in DM threads, not on
storefronts. Today the money then moves as a direct MoMo transfer: invisible to
Makola, fee-free, and unprotected for the buyer. A pay link is a shareable URL
the merchant drops into the chat; the buyer taps, pays MoMo, and a real order
with a receipt exists. Every paid link is a fee-generating transaction, and the
created → opened → paid funnel is direct demand-validation telemetry.

Pay links ship standalone. Spec 2 (Buyer Protection) layers a payout-hold on
top of the orders this flow produces; nothing here depends on it.

## Decisions (agreed during brainstorm)

1. **Link payload: both catalog and custom.** Catalog links point at a
   product/variant and are reusable; custom links carry a negotiated
   amount + description and are single-use.
2. **Delivery collection is a per-link merchant toggle.** On → buyer enters
   name/phone/address before paying. Off → payment-only; delivery stays in
   the DM thread.
3. **Creation surfaces: web admin + JSON:API.** Admin LiveView now; the Ash
   resource is also exposed through the existing mobile `ApiRouter`
   (`X-Store-ID` tenancy). The Flutter screen is out of scope.
4. **Custom amounts become ad-hoc line items** (Approach A). `LineItem.variant_id`
   becomes nullable; the existing snapshot fields (`product_title`,
   `unit_price`) carry the deal. Rejected: hidden auto-created catalog
   products (silent-leak risk across storefront/search/sitemaps/feeds/WhatsApp
   sync) and order-less payments (forks the money path away from
   fees/settlement/refunds and starves Buyer Protection of a delivery to
   confirm).

## Domain model

### New resource: `Emakola.Orders.PayLink`

Tenant-scoped (`store_id`), in the Orders domain — it is a selling entry
point, like `CheckoutService`, not a payment record.

| Attribute | Type | Notes |
|---|---|---|
| `code` | string, unique | 8-char lowercase base32, no ambiguous chars; the public URL identifier (~40 bits, unguessable) |
| `type` | `:catalog \| :custom` | |
| `variant_id` | uuid, nil for custom | catalog links only; buyer picks quantity on the page |
| `title` | string, custom only | shown to buyer ("Custom kente dress — as agreed") |
| `amount` | integer minor units, custom only | store currency; validated ≥ 100 and positive integer |
| `collect_delivery` | boolean | the per-link toggle |
| `status` | `:active \| :paid \| :cancelled \| :expired` | `:paid` only meaningful for custom (single-use) links |
| `expires_at` | utc_datetime, optional | default: 7 days for custom links, none for catalog |
| `note` | string, optional | private merchant memo; never rendered to buyers |
| `opened_count` | integer | incremented on **connected** LiveView mount only — dead renders and WhatsApp link-preview prefetches must not count; funnel telemetry |
| `created_by_user_id` | uuid | |
| `protected` | boolean | added by spec 2 (`2026-07-30-buyer-protection-design.md`): inherits the store's `buyer_protection_enabled` at creation, per-link override |

### Changes to existing resources

- **`Emakola.Orders.LineItem`** — `variant_id` becomes `allow_nil?: true`,
  with a validation that variant-less lines carry `product_title` and
  `unit_price`. `DecrementStock` skips variant-less lines (no stock to
  decrement). This is the entire order-rail footprint: a repo-wide grep found
  exactly one `.variant` dereference in the Orders domain (`decrement_stock.ex`).
- **`Emakola.Orders.Order`** — nullable `pay_link_id`. Needed for the
  single-use claim (which order consumed the link); also gives the admin
  order page a "via pay link" badge and queryable funnel data.

## Buyer flow

1. `GET makola.io/pay/:code` — apex-scoped route (the `pay` label is already
   in the reserved-subdomain list, so no store can shadow it). Storefront-layout
   LiveView showing store name/branding. `opened_count` incremented on mount.
2. Page shows the item — catalog: product card + quantity picker; custom:
   title + fixed amount — and a form: name + phone always (receipts go out
   via SMS/WhatsApp), address fields only when `collect_delivery`.
3. "Pay" → `CheckoutService.checkout!` creates a real **pending order**.
   The service gains a custom-line path (`title` + `unit_price`, no variant)
   alongside the existing variant path; same transaction semantics. Customer
   resolution gains a find-or-create-by-**phone** option (new in the service;
   the Customers domain already supports phone-keyed identities from the
   WhatsApp-auth work).
4. Gateway initiation exactly as `checkout_live.ex` does today
   (`gateway.initiate_payment/1` → Paystack/Hubtel MoMo redirect). Existing
   webhook confirmation and payment-expiry (abandonment) rails apply unchanged.
5. On confirmed payment, custom links flip to `:paid` inside the webhook
   transaction with a `FOR UPDATE` claim on the link row (the race-guard
   pattern from the refunds work). If a second in-flight payment lands on a
   just-consumed link, it is **flagged for merchant refund attention** — never
   silently double-sold.
6. Confirmation page with receipt; existing `order_placed` notifications fire
   to both sides. Platform fee applies with **zero new code** — the orders
   produced are ordinary, so `PlatformFee`, settlement, payouts, and the
   merchant refund flow all work unchanged.

## Merchant surfaces

### Admin LiveView — `/admin/pay-links` (`Admin.PayLinkLive.Index`)

- List: status pill, type, amount, **opened / paid** funnel columns.
- Create modal: type toggle (product/variant picker vs custom title + amount),
  delivery toggle, optional expiry, private note.
- After create: link shown with **Copy** and **Share on WhatsApp** (`wa.me`
  URL prefilled with item, amount, and link — pasted straight into the DM
  thread where the deal happened).
- Actions: **cancel only.** No edit — a changed deal is a new link.
- Authorization: store members via the existing `:app` live_session auth;
  the resource policy mirrors other tenant-scoped merchant resources.
- Follows the Makola Admin design language (stat tiles, status pills,
  rich empty state).

### API

`pay_links` exposed via ash_json_api on the existing `EmakolaWeb.ApiRouter`
(create / list / cancel / read), `X-Store-ID` tenancy as with orders.

## Lifecycle, money, abuse

- **Expiry is lazy** — no Oban worker. `expires_at < now` is evaluated at page
  mount and re-checked at payment initiation. An expired link is just data.
- **Store lifecycle enforced**: the link page performs the same live-store
  check as the storefront resolver; suspended/blocked/archived stores render
  the unavailable page, never a checkout.
- **Rate limiting**: payment initiation sits behind the existing rate-limit
  plumbing (same posture as storefront checkout/auth).
- **Money rules**: integer minor units only; custom `amount` ≥ 100
  (no 1-pesewa spam); store currency.

## Error handling (buyer-visible states)

| State | Behavior |
|---|---|
| Expired / cancelled / consumed link | Friendly "this link is no longer active — contact the seller" page (no crash, no blank render) |
| Catalog link, insufficient stock | "Sold out" state shown before payment can initiate; re-validated inside `checkout!` |
| Payment abandoned | Existing payment-expiry worker cleans up the pending order |
| Second payment on consumed link | Order flagged for merchant refund attention |

Storefront LiveViews have no catch-all `handle_event/3` (a wrong event name
crashes the page), so the pay-link LiveView must be event-complete and tested
for every rendered control.

## Testing

TDD throughout, Mox for gateways, no real APIs:

- **Tenant isolation**: store A cannot read/cancel store B's links.
- **Resource**: code uniqueness/format, status transitions, custom-amount
  validation (≥ 100, integers), expiry defaulting.
- **CheckoutService custom-line path**: totals, fee math, no stock decrement,
  snapshot fields populated, transaction rollback on failure.
- **Single-use race**: two concurrent confirmed payments on one custom link —
  exactly one consumes it, the second flags for refund (`FOR UPDATE` claim).
- **Buyer LiveView** (Mox gateway): happy path both link types; expired /
  cancelled / consumed / sold-out states; form shape with delivery toggle
  on/off; `opened_count` increments.
- **Guard test**: a nil-variant order renders correctly in admin order show
  and order emails via snapshot fields — the loud-failure insurance for the
  nullable-variant change.
- **Admin LiveView**: create both types, cancel, WhatsApp share text.
- **API**: JSON:API create/list/cancel with `X-Store-ID`; cross-store denial.

## Out of scope

- Flutter app UI (API is ready for it; screen is separate-repo work).
- Buyer Protection payout-hold (spec 2 — layers onto these orders).
- Link edit/regenerate, bulk links, QR codes, link analytics beyond
  opened/paid counters.
- Multi-item custom links (one line per custom link).

## Success criteria

1. Full test coverage above green; `mix format`/`credo --strict` clean.
2. A merchant can create both link types in the admin, share via WhatsApp,
   and cancel them.
3. A buyer on a phone can open a link and reach the gateway redirect in ≤ 2
   form steps; paid custom links cannot be paid twice.
4. Funnel columns (opened / paid) visible in the admin list.
5. Post-launch (needs real Paystack keys, `LAUNCH_TODO.md` §6): first real
   paid link recorded with platform fee split correctly.
