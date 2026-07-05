# Emakola — Dropshipping Roadmap (Merchant-Managed Suppliers)

> Feature roadmap | Status: DS.1–DS.5 ✅ shipped · Trustless settlement (SP-series) 🟡 in review (#158/#159)
> Specs: `~/.claude/plans/let-brainstorm-how-we-typed-bachman.md` (DS) · `~/.claude/plans/let-brainstorm-on-dropshipping-serene-dahl.md` (SP)

## Vision

Let merchants sell goods they don't hold in stock, sourced from their own suppliers
(local wholesalers, importers — reachable by WhatsApp/SMS). When a customer orders, the
order is **split by source**, each supplier is **auto-notified to ship direct**, and the
merchant tracks **margin** and a **payout ledger** of what they owe each supplier.

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

## 🟡 Trustless Split Settlement — SP-series (NEW, 2026-06)

> **Status: in review** — PRs [#158](https://github.com/kojjob/emakola/pull/158) (core)
> and [#159](https://github.com/kojjob/emakola/pull/159) (integration), stacked.
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
| **SP1** | Payout identity — `StorePayoutAccount`, `Supplier.linked_store_id`, gateway `create_subaccount/1` | ✅ Data + gateway built; ⬜ merchant onboarding UI |
| **SP2** | Supply connections — wholesaler↔dropshipper handshake (`SupplyConnection`) | 🔵 Planned |
| **SP3** | Cross-store catalog sourcing — import wholesaler products; price/availability sync | 🔵 Planned |
| **SP4** | Cross-store order & fulfillment — wholesaler inbound dashboard; cross-tenant auth | 🔵 Planned |

**Done (built, TDD, full suite green):**
- [x] `SplitCalculator` — pure 3-way split off margin, integer minor units, reconciles exactly
- [x] `Supplier.linked_store_id` bridge + `StorePayoutAccount` (subaccount + verification)
- [x] `PaymentSplit` (`pending→settled→reversed`) + `Payment.split_mode/split_code`
- [x] Gateway `create_subaccount/1` + `:split` on `initiate_payment/1` (Paystack flat split)
- [x] `DropshipSettlement` (resolve→split or fallback) + `OrderSettlement` (reconciles to `order.total`, folds delivery−discount into dropshipper share)
- [x] `CheckoutLive` wired; `PaystackWebhookHandler` settles on success / reverses on refund

**Remaining:**
- [ ] **SP1 onboarding UI** — merchant screen to create a payout subaccount and verify it
- [ ] **Refund clawback** — debit reversed splits against future payouts (currently splits only flip to `:reversed`)
- [ ] **SP2–SP4** — the supplier-network marketplace
- [ ] Ops confirms: Paystack txn-fee bearer; verify Paystack Ghana supports **MoMo as a subaccount destination** (else Transfers)

---

## Beyond MVP (not scheduled)
- API/inventory sync with supplier systems.
- Per-supplier returns/RMA flow.
- Stripe Connect gateway for international/USD (core is gateway-neutral; Stripe doesn't serve Ghana/Nigeria local payments — it owns Paystack).
