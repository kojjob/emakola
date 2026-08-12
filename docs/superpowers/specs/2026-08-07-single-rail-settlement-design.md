# Single-Rail Settlement — "money in → ledger rows → money out" (design spec)

**Date:** 2026-08-07 · **Status:** design approved in brainstorm; pending spec review
**Owner:** Kojo · **Scope:** payments, payouts, escrow/holds, storefront charge sites.
**Pay-links are excluded** — see the amendment below.
**Supersedes:** `2026-08-02-internal-settlement-design.md` ("One Ledger, Two Rails") as the
target architecture. That design shipped (P2 #373, P3 #374) and is live; this spec is the
deliberate simplification of it, not a bug fix.

> **Amendment — 2026-08-12: pay-links are out of scope.**
>
> This spec was written on 2026-08-07 without reference to SplitPay
> (`~/Projects/split_payment`), a standalone multi-party settlement engine Kojo is
> building; grepping this document and its P1 plan for "SplitPay" returned zero hits.
> The two designs collided on 2026-08-12: this one deliberately accepts platform custody
> of all funds as float, while SplitPay is non-custodial by design.
>
> **Ruling (Kojo, 2026-08-12): they coexist.** Makola's own commerce settles here —
> storefront, dropship, buyer-protection holds, **susu/lay-away**, group-buy, preorder,
> all unchanged. **Pay-link charges settle through SplitPay instead**, in production.
>
> Nothing else in this spec changes. Escrow stays whole, susu stays here, the ledger,
> reversal rule, payout rail and migration phases are all as written — except that P1's
> flip must not capture `PayLinkLive` (§3.5, amended below).
>
> Full reasoning, including what the carve-out costs and what it deliberately does not:
> `split_payment/docs/superpowers/specs/2026-08-12-splitpay-makola-boundary.md`.

## 1. Problem

The two-rail settlement system works, but its owner does not trust it — and for a money
system that is a defect in itself. The distrust has one root: **the same business event
means different things on each rail.**

- A *reversal* on the gateway rail is fully recoverable (money already left at charge
  time); on the internal rail it nets at source before claim but is fenced by a frozen
  `netted_reversal_amount` after claim. Reconciling these produced the "no-double-claw"
  invariant and the three-way `effective_netted` formula — correct, verified, and too
  complex to audit by reading.
- *Payable* requires knowing the rail: `Payment.outstanding_for_payout` (filters
  `split_mode`) for one population, `PaymentSplit.payable_internal` for another.
- *Held/escrowed* charges (`split_mode: :none`) have **no ledger rows at all** — the four
  escrow flows live outside the ledger that is supposed to be the source of truth.

Every one of these dualities exists only because charges settle over two rails:
Paystack subaccount splits (no custody, no transfer fees, requires verified parties)
and the internal ledger (covers everyone else).

## 2. Decisions (made 2026-08-07)

1. **One rail: everything internal.** Every charge lands in the platform's Paystack
   account; one ledger allocates it; payouts transfer out. Custody (platform holds all
   funds as float) and per-transfer Paystack fees are **accepted** as the price of a
   model that can be audited by reading. Fees are amortised by batching payouts.
2. **Escrow features are preserved whole.** Buyer protection, susu, group-buy escrow,
   and preorder deposits keep their exact business behaviour. (Explicit owner
   instruction: "don't forget the escrow features.")
3. **Payouts stay manually approved** by staff for now; batching (weekly default) is
   config; a future scheduler remains a flip, exactly as today.
4. **Rejected — gateway-everything:** re-erects the sell-gate that blocked unverified
   merchants from earning; that gate was deliberately removed and stays removed.
5. **Rejected — surface-only simplification:** renames and docs would leave the dual
   semantics intact, which is the thing distrusted.

## 3. Design

### 3.1 The ledger

`Emakola.Payments.PaymentSplit` — already a guarded, integer-math near-ledger with
five roles, a `:pending → :settled` state machine, and a reversal/recovery sub-ledger —
**becomes the one ledger** rather than being replaced. History stays readable in place.

- Every charge produces its allocation rows at charge time: merchant share,
  wholesaler share(s), platform fee. Rows sum exactly to the charge amount.
- Fee truth is unchanged: `PlatformFee` (200 bps own-stock) and `SplitCalculator`
  (1000 bps dropship margin) remain the only modules that compute fees.
- `settlement_method` is retired: there is only one method. `Payment.split_mode`
  stops partitioning new charges (see §3.5 for the legacy tail).
- **Payable** is one predicate, defined once, on the resource:
  `settled ∧ not held ∧ not paid out ∧ net of reversals > 0`.

### 3.2 One reversal rule

A refund posts negative ledger events against the same allocation it reverses.

- Allocation not yet paid out → the negative **nets at source**; the payable amount
  shrinks, possibly to zero.
- Allocation already paid out → the negative **carries forward** as a debit against
  that recipient's future payables. No claw-back machinery, no frozen snapshots.

This single rule replaces: the no-double-claw invariant, `netted_reversal_amount`
freezing at claim, the three-way `effective_netted` formula, and the rail-conditional
recovery pipeline — all of which existed to reconcile two reversal semantics that no
longer coexist. `RefundLiability`'s reserve/apply/rollback survives only as the
mechanism that records the negative events and carried-forward debits.

Invariant: reversals against a charge never exceed the charge (testing invariant 5).
A recipient's *balance* may go negative via carry-forward and is settled against
future earnings before any new payout.

### 3.3 Escrow — kept whole, made visible

All four hold flows keep their business behaviour exactly:

| Flow | Held until | Release |
|---|---|---|
| Buyer protection (TC-2) | delivery confirmed | rows become payable |
| Susu (TC-3) | plan completes → converts to a protection hold → delivery | rows become payable |
| Group-buy escrow | group completes | rows become payable |
| Preorder deposit | fulfilment | rows become payable |

What changes is only what a hold *is*. Today a held charge is `split_mode: :none`
with **no allocation rows** — escrowed money is invisible to the ledger. In the new
model every charge, held or not, gets its rows at charge time; a hold flags those rows
**not-yet-payable** (`hold_reason` on the rows, mirroring today's
`payout_held`/`payout_hold_reason` on the payment). Release flips the flag; nothing
else moves.

- `ProtectionHolds.ensure_hold/1` and its fee/net snapshotting stay as built — the
  snapshot now corroborates ledger rows instead of substituting for them.
- Susu chunks: each contribution is a charge whose rows carry `hold_reason:
  :susu_plan`; completion re-tags to the protection hold; expiry/cancel refunds via
  §3.2 (`SusuRefunds` unchanged in behaviour).
- Escrowed money appearing in the same ledger as everything else is itself a trust
  win: one place answers "where is every pesewa?"

### 3.4 Payouts

The hardened rail is kept verbatim: `PayoutService` FOR-UPDATE claim →
`PayoutWorker` idempotent transfer (unique `transfer_reference`) → webhook finalize
with balance re-release → settlement-batch reconciliation. Payouts cover merchants
**and** wholesalers by MoMo transfer. Batched weekly by default (config); triggered
by manual staff approval, unchanged. A recipient with a carried-forward debit (§3.2)
has it deducted before anything is claimable.

### 3.5 Migration — three phases, no backfill

- **P1 — the flip.** Route all new **storefront** charges internal.
  `OrderSettlement.prepare/2` already emits `:internal`; this phase removes the preceding
  `:dropship_split`/`:platform_fee` gateway outcomes from routing so `:internal` (or a
  hold) is the only result. Exit test: every new storefront charge has ledger rows that
  sum to its amount and include a platform-fee row.

  **Amended 2026-08-12 — `PayLinkLive` is excluded from the flip.** The original text
  read "Route *all* new charges internal… Both charge sites (`CheckoutLive`,
  `PayLinkLive`) already share `persist_payment!/2`," which would have captured
  pay-links. Under the coexistence ruling, `PayLinkLive` routes to SplitPay via the
  `RailPolicy` seam on `feature/split-pay-extraction` (commit `1f23d2db`), not to the
  internal ledger. The shared `persist_payment!/2` is exactly what makes this a routing
  decision rather than a fork — but the routing must now distinguish the two sites,
  which the original phrasing assumed it would not have to.

  P1's own plan document is unaffected: it contains no pay-link tasks (grepped).
- **P2 — one reversal rule.** Adopt §3.2 for all internal charges; retire the frozen
  `netted_reversal_amount` path for new claims. Holds gain their ledger rows (§3.3).
- **P3 — deletion.** When in-flight gateway-rail payments have drained (all splits
  settled/paid or reversed), delete: the gateway-share branch of routing,
  `settlement_method` conditionals, the three-way `effective_netted`, subaccount
  share wiring at charge time. Grandfathered history stays readable; no backfill —
  retroactive re-fee-ing would be wrong.

Each phase lands independently green and is independently revertible.

### 3.6 Testing — invariants as the spec

Property tests are the trust anchor; they state the whole system:

1. Rows of a charge sum exactly to the charge amount (integer math, no residue).
2. Every charge carries a platform-fee row unless explicitly fee-exempt.
3. `payable` never double-counts an allocation across two payouts (claim is exclusive).
4. Held rows are never claimable, whatever their state otherwise.
5. Total refunded against a charge never exceeds the charge.
6. A recipient's lifetime payouts never exceed lifetime allocations net of reversals.
7. Susu: sum of a plan's contribution rows equals `contributed_amount` at all times.

## 4. Non-goals

- No change to fees (200 bps / 1000 bps), gateways, or webhook contracts.
- No payout scheduler (remains a future flip).
- No mobile-app work: settlement is invisible to the merchant API.
- No backfill of pre-flip payments.

## 5. Open risk, stated honestly

Float custody concentrates regulatory and operational risk on the platform account
(accepted, decision 1). Mitigations in scope: the ledger equals the account by
construction (invariant 6 across all recipients ≈ account balance), and batch
reconciliation already exists. Anything beyond that — trust accounts, float
insurance — is a business decision outside this spec.

> **Amendment — 2026-08-12: the first mitigation no longer holds as written.**
>
> "The ledger equals the account by construction" was true when one ledger explained one
> account. With pay-links settling through SplitPay it is false: **SplitPay is
> non-custodial and the tenant is Makola, so pay-link money lands in this same Paystack
> account** while `PaymentSplit` knows nothing about it. `PaymentSplit` now explains a
> *subset* of the account, and a reconciliation that assumes otherwise reports every
> pay-link row as an unexplained credit.
>
> The mitigation is repaired by partitioning rather than abandoned. All three reference
> prefixes are already disjoint — `PAY-` here (`lib/emakola/payments/gateways/paystack.ex`),
> `SP-` SplitPay charges, `SPT-` SplitPay transfers — so each system reconciles only the
> slice its prefix claims, and rows matching *no* known prefix become the real exception
> queue. That is money in this account no ledger claims, which is what invariant 6 was
> protecting and what nothing currently looks for.
>
> Match the full prefix including the hyphen: `SP-` and `SPT-` are ambiguous without it.
> The prefixes are disjoint by luck, not design; SplitPay pins its half in
> `test/split_pay/provider_reference_prefixes_test.exs`, and **`PAY-` has no mirror test
> here yet.** Design:
> `split_payment/docs/superpowers/specs/2026-08-12-reconciliation-under-two-ledgers.md`.
>
> Note this changes no regulatory exposure. The float sits in Makola's account either
> way; only the bookkeeping is split. The custody question in decision 1 is unaffected —
> though it is now worth asking a lawyer about **Makola** holding susu contributions and
> buyer-protection escrow in that float, which the licence research
> (`split_payment/docs/research/2026-08-11-psp-licence-paths.md`) frames only for SplitPay.
