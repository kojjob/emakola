# Makola Book (Pay Later) — Design

**Date:** 2026-07-30
**Status:** Approved (brainstorm with Kojo, 2026-07-30)
**TC-5**, extending the Ghana trust-commerce series. Composes with TC-1
(link machinery), TC-2 (delivery confirmation, deposit protection), TC-3
(chunk-payment mechanics, signed-link authority — a pay-later balance is an
*inverted susu*: goods first, then flexible chunks to zero).

## Purpose

Market traders already run informal BNPL: trusted regulars take goods and
pay later, tracked in "the book." Makola Book digitizes that trade credit —
deposit via link, tracked balance, automated MoMo collection, and a
repayment history that compounds into the platform's underwriting dataset.
It is **not lending**: no interest, no late fees, the merchant extends the
credit exactly as they do today. (Regulatory posture: trade credit, not a
BoG-licensed loan product — sanity-check with counsel before launch.)

Klarna's moat is underwriting data, not capital. This is rung one of the
credit ladder: merchant-risk book credit generates repayment data at scale;
rung two (licensed partner BNPL) and rung three (platform-funded) become
underwritable decisions later instead of gambles.

## The spine invariant

> **A buyer's pay-later limit never exceeds the profit their platform
> history has already generated.**

Every customer is self-insured: at the moment anyone defaults, they burn
less than they already brought in — so even a 100% default rate among
qualified buyers cannot make the program lose money overall. Selection
beats collection; every other mechanism below only trims losses further.
All limit/tier constants are config, calibrated against this rule.

## Decisions (agreed during brainstorm)

1. **Risk bearer: the merchant** (trade credit, as their book today), with
   expected loss engineered down by deposit floors, earned eligibility,
   and the network freeze. The platform never lends.
2. **Two-tier eligibility ("1 AND 2")**:
   - **Platform tier** — 2 delivered-and-confirmed orders anywhere OR 1
     completed susu plan → small portable limit (default GH₵50) at any
     participating store; grows one step per cleanly repaid plan.
   - **Store tier** — ≥ 3 delivered orders at a specific store → a higher
     limit at that store (relationship bonus, also growth-stepped).
   Delivery confirmation (TC-2 rails: OTP / signed-link buyer confirm) is
   what qualifies an order — self-orders can't farm eligibility, and a
   buyer whose phone matches the merchant's is excluded outright.
3. **Repayment: flexible chunks + deadline** (inverted susu), not fixed
   installments. Merchant sets deposit and deadline within config bounds.
4. **Default: deadline + 7-day grace → platform-wide freeze.** Clearing
   the balance restores standing (the wobble stays on record).
5. **No interest, no late fees, v1.** Keeps the trade-credit posture clean.

## Domain model

### Platform-wide identity: the phone

Customers are per-store records in this codebase, so cross-store standing
keys on the **normalized E.164 phone** (the WhatsApp-auth rails already
verify and normalize phones).

### New resource: `Emakola.Payments.PayLaterStanding`

**Global (not tenant-scoped)**, one row per phone: qualification progress,
clean-repayment count, current platform-tier limit, open exposure, freeze
state (`frozen_at`, `frozen_plan_id`). Privacy rule: a merchant sees only
the buyer's **tier and available limit** — never other stores' history.

### New resource: `Emakola.Orders.PayLaterPlan`

Tenant-scoped; the credit lifecycle for one deal. The order remains an
ordinary commerce record pointing at it (`order.pay_later_plan_id`).

| Attribute | Notes |
|---|---|
| `code`, `customer_phone` | link bound to the qualified buyer's phone; works for no one else |
| `total_amount`, `deposit_amount`, `balance_due` | integer minor units; deposit within config bounds (default 40%, min 30%) |
| `deadline` | merchant-set within bounds (default 4 weeks, max 8); grace 7 days |
| `status` | `:offered → :active → :settled \| :defaulted \| :cancelled` (active on deposit paid; defaulted after deadline + grace; cancelled if the deposit is refunded before shipping) |
| `fee_rate_bps` snapshot, `note`, `created_by_user_id`, timestamps | as the other link resources |

Open `balance_due` across a buyer's active plans counts against their
limit — concurrent plans can never exceed it (checked under a standing-row
claim, the `FOR UPDATE` pattern).

### Config constants (calibrated to the invariant)

| Constant | Default |
|---|---|
| Platform-tier starting limit | GH₵50 |
| Store-tier starting limit | GH₵150 |
| Growth step per clean repayment | +GH₵50 |
| v1 limit cap | GH₵500 |
| Deposit default / minimum | 40% / 30% |
| Deadline default / max, grace | 4 weeks / 8 weeks, 7 days |

## Flows

**Merchant** creates a pay-later link from the pay-links page (fourth link
type): enters the buyer's phone → sees tier + available limit (or "not
qualified") → sets item/total, deposit, deadline → shares the link in the
DM.

**Buyer** opens the link (valid only for their phone, verified by OTP to
that phone on first open) → pays the deposit → order is created, goods
ship → receives the signed **balance page** (progress bar, chunk field,
deadline countdown, reminders at 7 days and 1) → chunks the balance to
zero → plan `:settled`, standing improves, limit steps up.

**Money** is simple because the goods already shipped: deposit and every
chunk are ordinary split-at-charge payments — merchant net to their
subaccount immediately, platform fee as the remainder, nothing held. If
the store has Buyer Protection on, the **deposit** holds until delivery
confirms (TC-2 composition); balance chunks always settle normally.

**Default**: an Oban sweep marks overdue plans (deadline + grace)
`:defaulted` → standing frozen platform-wide, merchant notified, buyer
nudges continue. Paying the balance later flips the plan `:settled` and
unfreezes.

## Edge cases

| Case | Behavior |
|---|---|
| Concurrent plans exceeding the limit | Blocked at offer time under the standing-row claim; open balances always count against the limit. |
| Buyer phone = merchant phone | Excluded from eligibility outright (self-order farming). |
| Store suspended mid-plan | New plans pause; **balance collection continues** — money owed doesn't pause. |
| Merchant forgives early | May mark a plan `:settled` early (their prerogative; recorded as merchant-settled, still counts as clean). |
| Partial forgiveness | Out of scope v1 — settle early or hold to terms. |
| Defaulted buyer repays | Plan settles, freeze lifts, the default event stays on the standing record. |
| Deposit refunded (protection/dispute) before shipping | Plan cancelled; no credit was extended; standing untouched. |

## Testing

- **The invariant test**: no reachable state where a buyer's open exposure
  exceeds their tier limit (property-style across offer/deposit/chunk/
  default transitions, concurrent offers included).
- **Eligibility**: both tiers unlock at exact thresholds; only
  delivery-confirmed orders count; self-order exclusion; susu completion
  path.
- **Freeze lifecycle**: default freezes platform-wide (second store denied),
  repayment restores, event persists.
- **Sweep**: deadline + grace math, idempotent re-runs.
- **Authority**: link is phone-bound (wrong phone cannot open/pay);
  signed balance page semantics as TC-3.
- **Money**: per-chunk fee math; deposit-protection composition (TC-2 on);
  balance settles normally while deposit is held.
- **Privacy**: merchant-visible standing is tier + limit only.
- Standard resource/tenancy/LiveView/notification coverage; the standing
  resource's *global* scope gets an explicit cross-store read-policy test.

## Out of scope (v1)

- Interest, late fees, penalties of any kind.
- The mutualized default pool (Layer 4 — needs volume).
- Partner or platform-funded BNPL (rungs two and three).
- Credit bureau reporting; formal collections.
- Merchant-set custom limits above the platform cap.

## Success criteria

1. Tests above green; `mix format` / `credo --strict` clean.
2. The invariant holds by construction and by test — reviewer can point to
   the single choke point where exposure is checked.
3. End-to-end: qualify (2 delivered orders) → offer → deposit → ship →
   chunk to zero → limit steps up; and the default path freezes then
   restores on repayment.
4. A merchant checking an unqualified phone gets a clear "not yet — here's
   what unlocks it" answer (which is itself a susu/pay-link sales pitch).
5. Post-launch: first real settled plan; program-level loss provably
   bounded below program-level fees collected.
