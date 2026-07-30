# Buyer Protection (Escrow-Lite Payout Hold) — Design

**Date:** 2026-07-30
**Status:** Approved (brainstorm with Kojo, 2026-07-30)
**Spec 2 of 4** in the Ghana trust-commerce series. Builds on
`2026-07-30-pay-links-design.md`; its held-funds pattern is the model
Susu lay-away (spec 3) will mirror.

## Purpose

The #1 blocker in Ghana/Nigeria social commerce is "what if the seller ghosts
after I pay?" Buyer Protection holds a protected order's money in the platform
account until delivery is confirmed, then pays the merchant out through the
existing payout engine. It is the honest justification for the platform fee —
and the claim a direct MoMo transfer to an Instagram stranger can never make:
**"Pay with Makola Protection."**

Almost no new money rails are needed. The two hard parts already exist:

- **Disbursement**: `PayoutService` already gathers un-split successful
  payments and pays them via MoMo Transfer (admin-approved, idempotent,
  `Payout` ledger). Holding money is *not attaching the merchant's gateway
  share at charge*; releasing is making the payment payout-eligible.
- **Delivery confirmation**: `FulfillmentDeliveryProof` is an existing
  short-lived, attempt-capped customer OTP proving physical delivery, on the
  fulfillment lifecycle `pending → notified → shipped → delivered`.

## Decisions (agreed during brainstorm)

1. **Opt-in: merchant store-level toggle + per-pay-link override.** Default
   off. Buyer sees a "Protected by Makola" badge whenever it applies. The
   merchant trades cash-flow delay for a trust badge that converts strangers.
2. **Release triggers: first of (a) delivery OTP verified, (b) buyer taps
   "I received it", (c) auto-release 5 days after the fulfillment reaches
   `delivered`** — unless a complaint has frozen the hold. Merchant-marked
   `delivered` alone never releases; it only starts the timer.
3. **Disputes v1: freeze + existing tools.** A complaint freezes auto-release.
   The merchant can refund (existing flow); platform staff can force-release
   or refund from a small queue. No formal arbitration workflow.
4. **Scope: own-stock orders and pay-link orders only.** Dropship split
   orders are excluded — their trustless multi-party split happens at charge
   by design (SP-series), and holding it would unwind that model.

## Money flow

**Charge time.** When protection applies, `OrderSettlement.prepare` returns a
new `:protection_hold` mode: **no merchant share attached**, so the full
charge lands in the platform main account. Fee/net are computed by
`PlatformFee.calculate/2` and **snapshotted** — a later fee-rate change never
alters an in-flight hold.

**Fee accounting is new at release.** Verified: today's un-split payout path
sums payments at full value (no fee). Released protected payments must enter
the payout backlog at their snapshotted **net** — the merchant receives
exactly `net`, the same fee as an unprotected order; protection costs nothing
extra. (Adjacent observation, not in scope: the existing un-split path means
no-subaccount merchants are paid out fee-free today — a revenue leak worth a
separate decision.)

**Refund during hold** is simpler than a normal refund: the money is still in
the platform account, so the existing refund flow applies with no clawback.
A completed full refund closes the hold as `:refunded`.

## Domain model

### New resource: `Emakola.Payments.ProtectionHold`

One per protected payment, created on webhook-confirmed payment success.
Tenant-scoped, an auditable state machine. A separate resource (not flags on
`Payment`) keeps the lifecycle clean, anchors complaints and the staff queue,
and establishes the held-funds pattern Susu will reuse.

| Attribute | Type | Notes |
|---|---|---|
| `payment_id`, `order_id` | uuid | |
| `amount`, `fee`, `net` | integer minor units | snapshots; invariant `fee + net == amount` |
| `status` | `:held → :released \| :refunded` | |
| `frozen_at` | utc_datetime, nil | a freeze is a flag, not a state — a frozen hold is still `:held` |
| `release_after` | utc_datetime, nil | set to delivered-at + 5 days when the fulfillment hits `delivered` |
| `released_at` | utc_datetime | |
| `release_reason` | `:delivery_otp \| :buyer_confirmed \| :auto_timer \| :staff` | |
| `complaint_reason` | `:not_received \| :not_as_described \| :other` | |
| `complaint_text` | string | |
| `resolution` | `:merchant_refunded \| :released_by_staff \| :refunded_by_staff` | |

### Changes to existing pieces

- **`PayLink`** gains `protected :boolean` — inherits the store setting at
  creation, per-link override. (Cross-referenced in the pay-links spec.)
- **Store settings** gain `buyer_protection_enabled :boolean`, default false.
- **`OrderSettlement.prepare/2`** gains the `:protection_hold` mode and the
  dropship-exclusion guard.
- **`FulfillmentDeliveryProof`** verify action gains a hook: verification of
  a protected order's delivery releases its hold.

## Release engine

Release flips the hold to `:released` (stamping `release_reason`) and makes
the payment payout-eligible at `net`. (Whether that's a hold-aware payout
query or stamping an adjusted payable amount on the payment is an
implementation-plan decision; the invariant — merchant receives exactly the
snapshotted `net` — is fixed here.) Triggers, first-wins:

1. **Delivery OTP verified** — the existing proof rail; strongest signal.
2. **Buyer confirmation** — "I received my order" on the tracking page,
   only via the signed link (see Security).
3. **Auto-timer** — an Oban worker sweeps holds with `release_after < now`,
   skipping frozen holds. Idempotent; unique per hold.

Multi-fulfillment orders release when **all** fulfillments confirm (v1
in-scope orders have exactly one). Disbursement then rides the existing
payout engine unchanged.

## Surfaces

**Buyer**
- Protection badge on protected pay-link pages and storefront checkout:
  "Payment held until you confirm delivery."
- Tracking page (`/track/:order_number`) gains a protection strip
  (held / released / refunded), **"I received my order"**, and **"Report a
  problem"** (reason + text; filing freezes the timer).

**Security — merchant self-release threat.** The merchant knows the order
number, so a bare tracking URL must never move money. Buyer actions render
only when the page is opened via the **signed tracking link**
(`Phoenix.Token`) delivered to the buyer's phone in the order SMS/WhatsApp;
plain order-number access is read-only. The OTP path is immune by
construction (the code goes to the buyer's phone).

**Merchant**
- Settings toggle with a plain-language cash-flow explanation.
- Admin order page: hold status, release ETA, release reason.
- Payouts page: "held" total alongside available balance.
- Pay-link create modal: protection override (only when the store toggle is on).

**Platform staff**
- `/platform/protection` — frozen-holds queue in the moderation-queue style:
  complaint context, force-release / refund actions, gated by
  `:manage_billing`, all actions written to the platform audit log. Includes
  a **stale** list: holds with no delivery signal after 30 days.

**Notifications** (existing dispatcher): "payment held" + signed link on
payment success; "confirm receipt — releases automatically in 5 days" on
delivered; release notice to the merchant; complaint/resolution notices to
both sides.

## Edge cases

| Case | Behavior |
|---|---|
| No delivery signal ever (merchant never fulfills, buyer silent) | Nothing auto-releases — rewarding non-delivery is the one forbidden outcome. At 30 days the hold surfaces as stale in the staff queue for a human decision. |
| Order cancelled / fully refunded while held | Refund closes the hold (`:refunded`). |
| Partial refund on a held payment | **Out of scope v1** (interacts with net math). Full refund only. |
| Complaint after release | Normal refund territory; outside protection. |
| Complaint on a hold already frozen | Updates text; one active complaint per hold. |

## Testing

Beyond standard resource/tenancy/LiveView coverage:

- **Merchant self-release threat**: bare order-number tracking access cannot
  confirm receipt or complain; signed-link access can.
- **Charge-path guards**: protection on → no gateway share attached;
  dropship order → protection refused; toggle off → behavior byte-identical
  to today.
- **Fee/net snapshot**: invariant holds; a fee-rate change mid-hold does not
  change the payout.
- **State machine**: each release trigger; freeze blocks the timer; refund
  closes; resolution unfreezes correctly.
- **Timer worker**: idempotent, unique per hold, frozen holds skipped.
- **Payout integration**: released holds enter the backlog at **net**, never
  full amount.
- **OTP hook**: proof verification on a protected order releases its hold.
- **Stale surfacing**: signal-less hold appears in the staff queue at 30 days.
- **Notifications**: dispatch assertions per lifecycle event.

## Out of scope

- Dropship split orders (v1 exclusion by design).
- Partial refunds on held payments.
- Formal dispute/arbitration workflow (evidence, deadlines, SLAs).
- Protection fees or premium tiers — protection is free; it *is* the fee's
  justification.
- Fixing the existing fee-free un-split payout path (flagged separately).

## Success criteria

1. Test coverage above green; `mix format` / `credo --strict` clean.
2. With the toggle on, a pay-link order's money demonstrably never reaches
   the merchant's subaccount at charge, and reaches them at `net` after each
   of the three release triggers.
3. A complaint freezes the timer; staff can resolve either way from
   `/platform/protection`, audit-logged.
4. With the toggle off, nothing anywhere changes.
5. Post-launch: first real protected transaction released and paid out.
