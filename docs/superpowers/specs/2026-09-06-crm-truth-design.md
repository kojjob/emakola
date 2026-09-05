# CRM Truth: Design

**Date:** 2026-09-06
**Status:** approved by Kojo ("IMPLEMENT ALL") from the review at
https://claude.ai/code/artifact/b2529277-5106-4876-abbc-a88be89d86e2
**Scope:** the merchant-facing CRM: `/admin/customers`, `/admin/customers/:id`,
`/admin/dashboard`, `/admin/reports`, `/admin/campaigns`, `/admin/reviews`,
`/admin/products`, and the storefront capture points that feed them.

## The problem

The CRM is an address book with the wrong numbers on it, and most buyers never
get into the book.

1. **Guest buyers never become customers.** Storefront checkout links a
   customer only when the buyer is signed in. A guest who types a phone and a
   name (the dominant Ghana flow) leaves an order with `customer_id: nil`. Pay
   links do the opposite: they find-or-create a customer from the phone. Every
   count on the customers page, the dashboard Buyers tile, and campaign reach
   runs on a minority base.
2. **Money made counts money not received.** The dashboard sums every
   non-cancelled order. Orders are created `:pending` and become `:confirmed`
   only when a payment succeeds. Unpaid orders sit inside the biggest number a
   merchant sees. `/admin/revenue` defines gross as successful payments.
3. **Attribution is captured on every order and read nowhere.** UTM and
   click-to-WhatsApp source is written at checkout and at pay links. Visit
   source is computed on every Reports load and never rendered.
4. **Visits are counted only on the shop home page.** WhatsApp and Instagram
   links land on product pages, so that traffic is uncounted and conversion is
   overstated. The ratio also mixes a calendar-day order window with a
   rolling-seconds visitor window.
5. **Every SMS goes to everyone.** One audience, no segments, real money per
   message.
6. Numbers that lie today: customers-list Total spent always GH₵ 0.00 (orders
   never loaded); Avg order value tile is the literal "N/A"; Buyers is
   customers created in the period, labelled three ways; PDF export counts
   cancelled orders as money and lists the ten newest products as top
   products. Export and Add customer buttons are inert. Notes says "coming
   soon" while the resource and its three domain functions exist.
7. Stored but shown nowhere: last bought, spend aggregates, tags, opt-out,
   addresses, notes, per-recipient campaign failures, wishlist counts, saved
   shops, newsletter emails, review ratings, delivery days.

## Global rules

- All money as integers in minor units (pesewas). Display formatting only in
  the presentation layer.
- Money definitions are locked (from the 2026-08-22 remediation) and must not
  be contradicted: gross = successful payments; net = gross minus platform
  fees; pending payouts from `PayoutService.outstanding_payments/1`. For the
  dashboard, "paid orders" = orders whose status is in
  `[:confirmed, :processing, :shipped, :delivered]`, because `:confirmed` is
  stamped only by a successful payment.
- Merchant-facing words: eight words or fewer per label. Names used:
  "Money made", "Waiting for payment", "Buyers", "Bought again",
  "Last bought", "Where orders came from", "Where buyers looked",
  "People saved your shop", "People want this", "Days to deliver",
  "Numbers that did not get it", "Carts left behind", segments "New",
  "Bought again", "Big spenders", "Gone quiet".
- No emoji anywhere. No invented numbers. Every metric names its window.
- Tenant scoping: every query carries `store_id`.
- Tests before code. `mix test`, `mix format`, `mix credo --strict`,
  `mix dialyzer` clean before each PR.
- Migrations: `mix ash.codegen` emits unrelated tables here; generate with
  `mix ash_postgres.generate_migrations --domains <Domain>` and hand-trim, or
  write the migration by hand and update only the touched snapshot.
- One PR per task below, each off `main`, merged bottom-up where stacked.

## The build, in order

### 1. Guest buyers become customers by phone
Storefront checkout resolves a customer for every order: signed-in customer
first; otherwise find-or-create by phone within the store (email when the
buyer gave one). Pay links already do this via a phone placeholder email;
storefront checkout adopts the same call. A one-off, idempotent Mix task
`mix emakola.backfill_guest_customers` links historical `customer_id: nil`
orders using the phone, name and email in `shipping_address`, and stamps
`last_order_at`. Customers created this way carry the buyer's phone and name.

### 2. Money made means paid
Dashboard money row, KPI cards, "Money each day" bars, and the orders line
chart use paid orders. A second line under Money made reads
"Waiting for payment: GH₵ X" for `:pending` orders in the period. "Buyers" is
the count of distinct customers on paid orders in the period, and the same
number carries the same label everywhere it appears.

### 3. Where orders came from
Reports gains two blocks: "Where buyers looked" (visits by source, from the
already computed `StoreVisits.by_source/2`) and "Where orders came from"
(orders and money by source). Order source is derived in one function,
`Emakola.Orders.Source.of/1`, from `pay_link_id`, `susu_plan_id`, and
`attribution` (`click_to_whatsapp`, `utm_source`), bucketed into the same
closed set StoreVisits uses. The dashboard's expanded section shows the top
three sources for the period.

### 4. Customers list tells the truth
List rows show real Total spent (non-cancelled orders), Last bought
("3 days ago"), and the tile row becomes Total, New this month, Bought again
(customers with two or more orders). Export downloads a CSV (name, phone,
email, orders, spent, last bought). Add customer opens a small form (name,
phone, optional email) using the existing `:create` action. Detail page:
totals exclude cancelled orders; order history pages by 20; Notes works
(list, add, delete); Last bought, default address, opt-out badge, tags as
chips, "Paid through a link" marker; a Message button that opens the chat
thread; a WhatsApp link on the phone; per-customer counts of returns, failed
payments, and cancelled orders.

### 5. Segments and campaign audiences
`Emakola.Customers.Segments` defines four segments over order history:
New (first paid order within 30 days), Bought again (two or more paid
orders), Big spenders (top fifth of customers by spend, minimum five
customers with orders), Gone quiet (one or more orders, none in 60 days).
Customers list shows them as chips with counts; selecting one filters the
list. Campaigns gain an audience select (Everyone plus the four segments);
the campaign stores its audience, the reach count and the send worker use
the same segment query.

### 6. Where buyers looked: product pages
`StoreVisit` gains `page` (`:home | :product | :pay_link`) and a nullable
`product_id`. Product detail and pay link pages record visits under the
same guard as the home page (connected socket, cart session present).
Reports "People who looked" counts distinct visitors across all pages;
conversion uses one calendar-day window for both numerator and denominator.
Reports gains "Looked, then bought" for the best sellers: visitors to the
product page against orders containing it, per product, in the window.

### 7. Counts already stored
Dashboard: "People saved your shop" (favourite stores count) and
"Days to deliver" (average from delivered orders in the period, via
`DeliveryMetrics`). Products list: "People want this" count per product
(wishlist items). Reviews page: average rating and count for published
reviews. Customers page: newsletter subscribers count with CSV export.
Campaigns: per campaign, "Numbers that did not get it" listing failed
recipients with their error.

### 8. Repeat rate
Reports gains "Bought again" for the window: share of paid orders placed by
customers who had a paid order before the window started, and the count of
returning versus new buyers.

### 9. Carts left behind
When a guest passes the checkout contact step (phone known) and no order is
placed within 2 hours, the checkout is recorded as left behind:
`Emakola.Orders.AbandonedCheckout` (store_id, phone, name, items snapshot,
cart total, cart_session_id, last_seen_at, recovered_order_id). A worker
marks a checkout recovered when an order with that phone lands within 48
hours. The dashboard work queue gains "Carts left behind" with a count; the
list shows phone, items, amount, time since, and a WhatsApp link with a
prefilled message. No automated sends (Meta-gated).

## Out of scope
Platform-side metrics (`/platform/*`). Open and click rates. Automated
WhatsApp recovery messages. Per-region conversion (refused on principle in
the Reports moduledoc).
