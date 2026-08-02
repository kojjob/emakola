# Internal Settlement — "One Ledger, Two Rails" (design spec)

**Date:** 2026-08-02 · **Status:** approved in plan review; pending spec review
**Owner:** Kojo · **Scope:** payments, suppliers, platform finance, storefront checkout

## 1. Problem

Merchants without capital — MoMo-only social sellers and Earn resellers — must be able to earn income. Today two things stop them:

1. **The sale itself is blocked.** `Emakola.Suppliers.NetworkCheckoutEligibility` refuses Earn/network checkout unless BOTH the reseller and every wholesaler have verified Paystack subaccounts. A new reseller cannot earn a single pesewa until payout onboarding completes.
2. **The fallback settlement path is a non-system.** When any party lacks a verified subaccount, `OrderSettlement.prepare/2` returns `{:no_split, ...}`, the charge lands `split_mode: :none` with **no ledger rows, no platform fee** (the confirmed revenue leak — unprotected un-split payments pay out gross), no refund recovery after payout, and wholesalers are paid by a manual "mark paid" click with no transfer rail.

Notably NOT the problem: MoMo-as-subaccount. `SubaccountCreationWorker` creates Paystack subaccounts with `settlement_bank: MTN/VOD/ATL` and a MoMo number — the only implemented onboarding path (ops-confirmed 2026-06-24, `docs/REVENUE-FIRST-90-DAY-PLAN.md`).

## 2. Current state on `main` (verified 2026-08-02 against 8b9ce000)

Charge-time routing precedence in `OrderSettlement.prepare/2`:

1. `:dropship_split` — every party verified → inline flat multi-split; platform fee = split remainder.
2. `{:hold, :buyer_protection}` (TC-2) — own-stock only, opt-in (`PayLink.protected == true`, else `Store.buyer_protection_enabled`, default false). Whole charge stays in the platform account (`split_mode: :none`, `payout_held: true, payout_hold_reason: "buyer_protection"`); `ProtectionHolds.ensure_hold/1` snapshots `fee`/`net` via `PlatformFee.calculate/2` into a `ProtectionHold` row; release stamps `payable_amount = net` on the payment; `PayoutService` pays `payable_amount || amount`. **Protected charges already take the platform fee.**
3. `:platform_fee` — own-stock, merchant verified → merchant net via subaccount share, fee = remainder.
4. `{:no_split, reason}` — verification failures and genuine split failures → `split_mode: :none`, no rows, no fee, gross payout. **This is the leak and the population this design converts.**

Held-payment reasons on main (all `split_mode: :none`, all outside the payout backlog until release): `"buyer_protection"`, `"susu_plan"` (TC-3; converts to `"buyer_protection"` at completion), `"group_buy_escrow"`, `"protected_preorder_deposit"`.

Two charge initiation sites duplicate the same wiring: `CheckoutLive.initiate_payment` and `PayLinkLive.initiate_payment` (both call `OrderSettlement.prepare/2`, `gateway.initiate_payment/1`, `Payments.create_payment`, `record_splits`).

Existing foundation reused by this design (unchanged on main): `PaymentSplit` near-ledger (5 roles, integer math, `:pending → :settled` guarded machine, reversal/recovery sub-ledger, `NULLS NOT DISTINCT` unique allocation identity), `RefundLiability` reserve/apply/rollback, `PartnerCredit` carve, the full payout rail (`PayoutService` FOR-UPDATE claim → `PayoutWorker` idempotent transfer → webhook finalize with balance re-release → settlement-batch reconciliation), `PlatformFee` (200 bps) and `SplitCalculator` (1000 bps margin fee) as the only fee-truth modules.

## 3. Decisions

- **Architecture: one ledger, two rails.** Gateway subaccount splits stay primary (no custody, no per-transfer fees). The internal rail replaces the `{:no_split, verification-failure}` fallback: ledger allocations recorded for every internal charge including the platform fee; allocations become payable balances; generalized payouts pay merchants AND wholesalers by MoMo transfer. Rejected: internal-first-everything (custody weight, transfer fees, rebuilding hardened rails); UX-patch-only (leaves the sell-gate, manual supplier pay, and the post-payout refund hole).
- **Sell-gate: both fully free** (Kojo, 2026-08-02). Drop both payout checks in `NetworkCheckoutEligibility`; any sale proceeds and all shares accrue. Mitigation is nudges ("GHS X waiting — add your MoMo number"), not gates.
- **Payouts: manual staff approval now, schema auto-ready** (Kojo, 2026-08-02). No scheduler built; a future cron is a config flip.
- **Protection stays as built.** TC-2/TC-3 hold machinery is untouched and keeps precedence over the new internal fallback, so no charge can be fee'd twice (routing is exclusive by construction).
- **Partition, don't migrate.** New `Payment.split_mode` value `:internal`: internal-rail charges carry allocation rows; `:none` remains the legacy/escrow mode with none. `outstanding_for_payout` (filters `:none`) and the new allocation-level payable read can never double-count. The existing prod `:none` payments are **grandfathered** — no backfill (retroactive fees would be wrong; the legacy rail must survive for the four hold flows regardless).
- **Per-charge single rail.** A charge is entirely `:gateway_share` or entirely `:internal_hold` (platform rows are always `:internal_hold` — that money stays in the main account on both rails). No mixed-rail charges.

## 4. Design

### 4.1 Ledger vocabulary (`PaymentSplit`)

New attributes: `settlement_method` (`:gateway_share | :internal_hold`, default `:gateway_share`; migration backfills `internal_hold` where `subaccount_code IS NULL` — historically only platform rows), `currency` (default `"GHS"`), `paid_out_at`, `payout_id`, `paid_amount` (frozen at claim), `netted_reversal_amount` (default 0).

New actions:
- `update :mark_paid_out` — requires `:internal_hold`, status `:settled`/`:partially_reversed`, unclaimed; freezes `paid_amount = amount - reversed_amount` and `netted_reversal_amount = reversed_amount`.
- `update :release_from_payout` — nils the claim fields, resets `netted_reversal_amount` (nothing was paid; reversals net at source again).
- `read :payable_internal` (nilable `recipient_store_id` arg) — `internal_hold ∧ role != :platform ∧ status ∈ [settled, partially_reversed] ∧ paid_out_at is nil ∧ amount > reversed_amount`. The split-level sibling of `Payment.outstanding_for_payout`; defined once, on the resource.
- `read :by_payout`.

`gateway_shares/1` switches from inferring on `subaccount_code` to filtering `settlement_method == :gateway_share` — un-overloading nil-subaccount.

### 4.2 The no-double-claw invariant (new)

On the gateway rail a reversal is fully recoverable (the money already left at charge time). On the internal rail a reversal landing **before** the split is claimed is netted at source (payable = `amount − reversed_amount`) and must NOT also be clawed from future earnings. `netted_reversal_amount`, frozen at claim and reset on release, is the fence: recoverable liability = `reversed − netted − recovered − reserved`. Gateway splits keep `netted == 0`, so the formula reduces to today's exactly. `RefundLiability.reserve_from_liabilities/4` updates accordingly; `add_to_platform/2` is hardened to SYNTHESIZE a `:platform` row when absent instead of silently dropping recovered money.

### 4.3 Transactional recording

New `OrderSettlement.persist_payment!/2` wraps `create_payment` + `record_splits!` in one `Repo.transaction`, and carries the `{:hold, ...}` shape's `payout_hold_attrs` through unchanged. Adopted at BOTH charge sites (`CheckoutLive`, `PayLinkLive`) in Phase 1 (behavior-preserving). `record_splits!` persists `settlement_method` + `currency`.

Internal allocation builders (dark until Phase 3):
- Own-stock: same `PlatformFee.calculate(order.total, platform_fee_rate_bps())` — fee parity with the gateway rail; merchant row `:internal_hold`, nil subaccount.
- Dropship: `DropshipSettlement.prepare_internal/3` — no subaccount requirement; linked suppliers get `recipient_store_id: linked_store_id`; UNLINKED suppliers' cost + dispatch fee folds into the dropshipper row (their `SupplierLedgerEntry` remains the manual obligation). Same `SplitCalculator` margin fee (1000 bps).
- Shared post-processing identical to the gateway rail (delivery-fee fold, `PartnerCredit.carve_sales_proceeds`, `RefundLiability.reserve!`, `sum_matches_total?`); after the carve, force `:internal_hold` + nil subaccount on all non-platform rows (the credit-partner carve sets a creditor subaccount unconditionally).

### 4.4 Internal payout engine

- `Payout.basis` (`:payments | :allocations`, default `:payments`).
- `PayoutService.prepare_internal_payout(recipient_store_id)` mirrors `prepare_payout/1` exactly: destination validated first; then one transaction — `payable_internal` read + `Ash.Query.lock("FOR UPDATE")` (the same serialization point that makes the legacy path double-pay-proof), currency partition, sum of `amount − reversed_amount`, create payout `basis: :allocations`, `mark_split_paid_out` each. New `momo_destination?/1` helper.
- Webhook: `release_payout_balance/1` additionally releases splits (`by_payout` → `release_from_payout`; the list is empty for the other basis — idempotent). `transfer.success` on an allocation payout projects supplier ledger settlement before notifying.
- `PayoutWorker`: generalize the reason string; nothing else (verified payee-agnostic — reference-keyed idempotency).
- Supplier obligation unification: `SupplierLedgerEntry` gains `settlement_source` (`manual | platform_payout | split_gateway`) + `payment_split_id`, actions `claim_for_platform_settlement` and `mark_platform_paid`; `Supplier.outstanding_balance` counts only `:manual`; `settle_splits` claims matching entries (gateway splits claim + mark paid immediately — fixes today's pre-existing double-obligation on the gateway rail, an intentional behavior change with its own test).
- FinanceStats (additive, on top of TC-2's `payable_amount` shape): outstanding = legacy sum + Σ payable nets; per-store merges payable splits keyed by **`recipient_store_id`** (a wholesaler's earnings appear under the wholesaler's store); `payouts_ready?` switches from verified-subaccount to MoMo-destination-present (what transfers actually require).
- `/platform/finance` approve prepares BOTH bases per store; recent-payouts table shows basis.

### 4.5 The flip (checkout, eligibility, visibility)

- `prepare/2` routing becomes: `:dropship_split` → `{:hold, :buyer_protection}` → `:platform_fee` → **`:internal` (new — all verification-failure reasons: `:payout_unverified`, `:dropshipper_payout_unverified`, `:wholesaler_payout_unverified`, `:supplier_not_linked`)** → `{:no_split, ...}` only for genuine failures (`allocation_sum_mismatch`, negative non-platform allocation). Internal mode returns `shares: []`; the platform fee is always taken.
- Both charge sites pass `:internal` through `split_mode/1` and attach a gateway split only when `shares != []` (the `{:hold, ...}` clauses stay as-is).
- `NetworkCheckoutEligibility`: drop both payout checks (decision). The coupon hard-block stays.
- `SalesTeams.settlement_base/1`: no code change — internal charges now carry exactly one `:merchant`/`:dropshipper` row, so attributed sales settle identically on both rails (intentional parity; explicit test + release note).
- Visibility: merchant payouts page shows the accrued internal balance (`payable_internal` sum via `assign_async`) + an "add your MoMo number" nudge when balance > 0 and no destination; same nudge on the supplier admin page.

## 5. Phasing (stacked PRs, bottom-up)

- **Phase 1 — ledger vocabulary + transactional recording.** Ships dark; zero checkout behavior change. Migrations (hand-written per repo convention; `ash.codegen` broken repo-wide): `payment_splits` columns + index `(recipient_store_id, settlement_method, paid_out_at)`; `payouts.basis`; `supplier_ledger_entries` columns. All §4.1–4.3.
- **Phase 2 — internal payout engine.** Rails live; payable population still zero. All §4.4.
- **Phase 3 — the flip.** The one deploy where behavior changes. All §4.5 + doc comments on `outstanding_for_payout`/FinanceStats describing the partition.

Rollout hazards, in order: (1) engine before accrual — P1/P2 fully deployed before P3, or unverified sellers' earnings strand; (2) `settlement_method` backfill runs inside the P1 migration before any code routes on it; (3) hold-flow safety is structural — all four `payout_held` reasons are `:none` with no rows, outside both payout populations; (4) internal splits (nil subaccount) matching main-account settlements in `stamp_settled_splits` is semantically correct — comment it; (5) Paystack's first-payout hold on new subaccounts: those stores auto-fall to the internal rail during the window — free bridge.

## 6. Invariants (each carries a test)

1. **Sum-exact**: Σ allocations == charge total at every stage (existing `sum_matches_total?` backstop; new end-to-end assertion through payout).
2. **No-double-pay**: FOR-UPDATE claim + stamping, both rails; transfer-failure release → fresh payout re-claims exactly once.
3. **No-double-count**: `:none` vs `:internal` partition; FinanceStats counts each pesewa once (legacy suites stay green untouched in P1/P2 as proof the legacy definition didn't move).
4. **No-double-claw**: reversal-before-claim nets at source and is not recoverable; reversal-after-claim recoverable only for the delta.
5. **No-double-fee**: routing exclusivity (protection wins before the internal fallback); fee-parity test — identical order through a verified vs unverified store yields the identical platform fee.
6. **Cross-rail isolation**: an escrow/held payment and a payable split are never co-claimed; each payout basis claims only its own population.

## 7. Not building (YAGNI)

Mixed-rail charges; migrating protection/susu/escrow onto the allocation ledger; non-payment-anchored ledger entries; Paystack balance checks / transfer polling / transfer-fee modeling; payouts to unlinked suppliers; Hubtel transfers; treasury or merchant-initiated withdrawals; migrating `outstanding_for_payout` itself; the auto-payout scheduler (schema-ready only).

## 8. Verification

Per phase: full `mix test` green + `mix format --check-formatted` + `mix credo --strict`; the money suites (`payment_split(_integrity)`, `refund_liability`, `order_settlement`, `outstanding_payments`, `payout_service`, webhook, finance, supplier) must pass untouched in P1/P2. After P3 in dev: seed an unverified store; checkout a dropship order via MoMo; assert `split_mode: :internal`, splits sum to charge, fee at 200/1000 bps; approve payout at `/platform/finance` with Mox-backed transfer; `transfer.success` marks paid + projects the supplier entry; a grandfathered `:none` payment still pays via the legacy path; a protected pay-link charge still holds + releases net (untouched).
