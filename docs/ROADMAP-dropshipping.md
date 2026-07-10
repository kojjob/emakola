# Emakola — Makola Earn / Dropshipping Roadmap

> Feature roadmap | Status: DS.1–DS.5 ✅ shipped · SP1/SP5 ✅ shipped · SP2–SP4 🔵 planned
> Specs: `~/.claude/plans/let-brainstorm-how-we-typed-bachman.md` (DS) · `~/.claude/plans/let-brainstorm-on-dropshipping-serene-dahl.md` (SP)

## Vision

Let merchants sell goods they don't hold in stock, sourced from their own suppliers
(local wholesalers, importers — reachable by WhatsApp/SMS). When a customer orders, the
order is **split by source**, each supplier is **auto-notified to ship direct**, and the
merchant tracks **margin** and a **payout ledger** of what they owe each supplier.

Makola Earn extends that private-supplier foundation into a verified supplier network for
people who cannot afford inventory. A wholesaler publishes an approved offer, a reseller
adds it to their branded storefront without buying stock, and the customer charge is
split directly between the wholesaler, reseller, and Emakola.

### Makola Earn product promise

> Start selling without buying stock. Choose trusted products, share them with your
> network, and earn from completed sales.

- No joining fee, required starter pack, inventory purchase, downline, or multi-level
  commission.
- Earnings come only from genuine product sales; income is never guaranteed.
- Offers show customer price, supplier net, reseller earnings, Emakola fee, delivery
  area, return terms, and supplier performance.
- Physical and digital offers are separate lanes with distinct fulfillment and return
  rules.
- Paystack splits funds at source. Emakola does not operate or advertise an escrow wallet.

### Locked decisions
| Decision | Choice |
|---|---|
| Model | Merchant-managed suppliers (private per store) |
| Supplier link | Variant-level (`variant.supplier_id`) — a product may mix suppliers |
| Orders | Mixed: one order → many fulfillments (per supplier + own stock) |
| Routing | Auto WhatsApp/SMS **and** manual mark-sent/resend fallback |
| Economics | Full payout ledger (cost_price → margin → owed/paid) |
| Inventory | Merchant-set `available` boolean (no stock counts for dropship) |

### Guardrails
- Money is **integer minor units** (pesewas/kobo), never floats.
- Every resource is **store-scoped** (`store_id` attribute multitenancy).
- TDD per phase (Red→Green→Refactor), 90% coverage on new code.
- Cost currency = store currency for MVP.

---

## Milestones

Each milestone is independently shippable. Value compounds: a merchant gets real utility
at DS.1, and each later milestone removes manual work.

### 🔵 DS.1 — Suppliers & Sourcing (Foundation)
**Goal**: A merchant can record suppliers and mark products as dropshipped from them.
**Depends on**: nothing (extends existing Catalog).
**Shippable value**: merchants can catalog who supplies what, with cost & availability —
useful even before any automation.

- [ ] `Emakola.Suppliers` domain + `Supplier` resource (name, contacts, payment_details, active)
- [ ] Store-scoped multitenancy + unique supplier name per store
- [ ] `Variant` gains `supplier_id`, `cost_price`, `available`
- [ ] Setting a supplier auto-sets `track_inventory: false`
- [ ] Storefront add-to-cart gates on `available` for dropshipped variants
- [ ] Register domain in `config/config.exs`; reversible migration
- **Exit criteria**: Supplier CRUD tests green, variant sourcing tests green, multi-tenant isolation verified.

### 🔵 DS.2 — Split Fulfillment (Keystone)
**Goal**: Orders fan out into per-source fulfillment groups.
**Depends on**: DS.1.
**Shippable value**: merchant order view shows which items go to which supplier — the
core operational unlock, even with manual handling.

- [ ] `Fulfillment` resource (order/store-scoped, status `pending→notified→shipped→delivered`, cancel) + status guard
- [ ] `LineItem` gains `fulfillment_id` + `cost_price` snapshot
- [ ] `CheckoutService` groups line items by `variant.supplier_id` → fulfillments
- [ ] `Order.status` derived from its fulfillments
- **Exit criteria**: mixed-cart checkout test (2 suppliers + own stock ⇒ 3 fulfillments), cost snapshot + status derivation tests green.

### 🔵 DS.3 — Supplier Routing & Notifications
**Goal**: Suppliers are automatically told what to ship and where.
**Depends on**: DS.2.
**Shippable value**: removes the merchant's manual "message the supplier" step — the
biggest time saver.

- [ ] `supplier_fulfillment_created` event + templates (items + ship-to address)
- [ ] `SupplierNotificationWorker` (clone of `OrderNotificationWorker`, idempotent, dedup)
- [ ] Auto-send on payment success when supplier has contact info → `:notified`
- [ ] Manual `mark_notified` / `resend` fallback
- **Exit criteria**: worker tests (supplier-addressed message, dedup, idempotency) green with mocked SMS/WhatsApp; manual fallback test green.

### 🔵 DS.4 — Payout Ledger & Margin
**Goal**: Merchant sees profit per order and tracks what they owe each supplier.
**Depends on**: DS.2 (cost snapshot), DS.3 (fulfillments in flight).
**Shippable value**: the financial picture — margins and supplier balances.

- [ ] `SupplierLedgerEntry` (one per supplier fulfillment, `amount_owed`, `owed→paid`)
- [ ] Supplier outstanding-balance aggregate
- [ ] `mark_paid` action (stamps `paid_at`)
- [ ] Per-order margin calculation `Σ(unit_price − cost_price) × qty`
- **Exit criteria**: ledger creation, balance aggregate, mark_paid, and margin tests green on known integer amounts.

### 🔵 DS.5 — Merchant UI
**Goal**: All of the above is usable from the admin dashboard.
**Depends on**: DS.1–DS.4 (UI can land incrementally per backing milestone).
**Shippable value**: non-technical merchants can operate the whole flow.

- [ ] Suppliers CRUD admin LiveView
- [ ] Variant editor: supplier select + cost_price + available toggle
- [ ] Order detail: fulfillments grouped by supplier, send/resend, tracking, margin
- [ ] Supplier detail: outstanding balance + ledger with mark-paid
- **Exit criteria**: LiveView tests for supplier CRUD, variant assignment, and order fulfillment actions green.

---

## Sequencing & dependencies

```
DS.1 ──► DS.2 ──► DS.3 ──► DS.4
  │        │        │        │
  └────────┴────────┴────────┴──► DS.5 (UI lands incrementally alongside each)
```

Strict order is DS.1 → DS.2 → {DS.3, DS.4 can parallelize} → DS.5. DS.5 slices can ship
as soon as their backing milestone is done (e.g., supplier CRUD UI right after DS.1).

## Risks & watch-items
- **Order status derivation** (DS.2): existing manual order actions must keep working for
  the merchant-only fulfillment group — regression risk on the current order flow.
- **Notification cost/abuse** (DS.3): auto-SMS to suppliers has real send costs; reuse the
  600s dedup window and gate on valid contact info.
- **Ledger integrity** (DS.4): one entry per supplier fulfillment, all integer math — no
  floating-point drift, no double-entry on retries.
- **Cross-currency** (out of scope): suppliers priced in a foreign currency is deferred.

## ✅ Trustless Split Settlement — SP-series (2026-06)

> **Status:** SP1 payout identity/onboarding and SP5 settlement are shipped. SP2–SP4
> remain the active Makola Earn build.
> Spec: `~/.claude/plans/let-brainstorm-on-dropshipping-serene-dahl.md`.

**Problem.** DS.1–DS.5 settle suppliers via a *manual* ledger — the customer's full
payment lands in the dropshipper's account first, who is then trusted to pay the supplier.
That trust gap is fraud-prone, and it blocks merchants with **no working capital** from
dropshipping at all.

**Solution.** Split the charge **at the gateway** (Paystack Multi-Split) so each party is
paid directly and the wholesaler's cut never touches the dropshipper's balance. **No
platform custody** (avoids Bank of Ghana PSP licensing). Platform fee = **% of dropship
margin** in basis points. Wholesalers are first-class Emakola stores (supplier network).

Decomposed into 5 sub-projects; **SP1 + SP5 built first** (the money rails).

| ID | Sub-project | Status |
|----|-------------|--------|
| **SP5** | Split settlement engine — `SplitCalculator`, `DropshipSettlement`, `OrderSettlement`, `PaymentSplit`, checkout wiring, webhook settle/reverse | ✅ Built (#158/#159) |
| **SP1** | Payout identity — `StorePayoutAccount`, onboarding UI, `Supplier.linked_store_id`, gateway `create_subaccount/1` | ✅ Shipped |
| **SP2** | Supply connections — wholesaler↔dropshipper handshake (`SupplyConnection`) | ✅ Shipped |
| **SP3** | Cross-store catalog sourcing — import wholesaler products; price/availability sync | 🔵 Planned |
| **SP4** | Cross-store order & fulfillment — wholesaler inbound dashboard; cross-tenant auth | 🔵 Planned |

**Done (built, TDD, full suite green):**
- [x] `SplitCalculator` — pure 3-way split off margin, integer minor units, reconciles exactly
- [x] `Supplier.linked_store_id` bridge + `StorePayoutAccount` (subaccount + verification)
- [x] `PaymentSplit` (`pending→settled→reversed`) + `Payment.split_mode/split_code`
- [x] Gateway `create_subaccount/1` + `:split` on `initiate_payment/1` (Paystack flat split)
- [x] `DropshipSettlement` (resolve→split or fallback) + `OrderSettlement` (reconciles to `order.total`, folds delivery−discount into dropshipper share)
- [x] `CheckoutLive` wired; `PaystackWebhookHandler` settles on success / reverses on refund

**Remaining (build in this order):**
- [x] **Refund reversal accounting** — partial/full refunds now persist cumulative,
  proportional `PaymentSplit.reversed_amount` without creating a duplicate ledger.
- [x] **Refund recovery** — row-lock and reserve unrecovered liabilities before
  gateway routing, net them from future recipient shares, apply/release them on
  payment success/failure, and reopen them proportionally on later refunds.
- [x] **SP2 supply connection foundation** — request/approve/reject/suspend/reactivate/
  terminate service with participant authorization and lifecycle tests.
- [x] **SP2 merchant UI** — connection inbox, invitations, active relationships, and
  approve/reject/suspend/reactivate/terminate controls.
- [ ] **SP3 shared offers and catalog sourcing** — physical/digital offers, markup and
  fixed-commission earnings, one-click listing, and source synchronization.
- [ ] **SP4 cross-store fulfillment** — wholesaler inbound queue, cross-tenant access,
  physical delivery proof, and protected digital grants.
- [ ] **Sales Kits and First Money journey** — ready-to-share content, tracked links, and
  guided activation through the first fulfilled sale.

### Locked Makola Earn decisions

| Decision | Choice |
|---|---|
| Settlement | Existing direct Paystack multi-split; no platform custody |
| Platform fee | 10% of reseller gross earnings on network offers |
| Earning models | Merchant-set markup within supplier bounds; supplier-set fixed commission |
| Eligibility | Browse/build before verification; verified payout required before checkout |
| Supply | Curated wholesalers plus approved existing Emakola stores |
| Fulfillment | Supplier ships physical goods; Emakola issues protected digital grants |
| Customer disclosure | “Fulfilled by verified partner” |
| Delivery proof | Customer OTP; quality evidence, not a settlement hold |
| Coupons | Ordinary merchant coupons excluded from network products in v1 |
| Recruitment | Single-level product sales only; never MLM/downline compensation |

### Concierge validation gate

Before building the full SP3 UI, run a 2–4 week managed pilot with 3 suppliers, 20
offers, and 10 prospective resellers using the existing private-supplier flow plus manual
Sales Kits. Proceed when at least 7 publish, 5 share, 3 make a genuine sale, and 90% of
paid orders fulfill successfully. Treat sharing-without-sales as a product/price/trust
problem and no-sharing as an activation/content/ICP problem.

The expanded pilot targets roughly 10 verified suppliers, 100 approved offers, and 50
zero-capital resellers. The north-star metric is resellers with at least one successfully
fulfilled sale per week—not registrations or catalog size.

---

## Beyond MVP (not scheduled)
- API/inventory sync with supplier systems.
- Per-supplier returns/RMA flow.
- Stripe Connect gateway for international/USD (core is gateway-neutral; Stripe doesn't serve Ghana/Nigeria local payments — it owns Paystack).
