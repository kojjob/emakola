# Susu Lay-away — Design

**Date:** 2026-07-30
**Status:** Approved (brainstorm with Kojo, 2026-07-30)
**Spec 3 of 4** in the Ghana trust-commerce series. Composes with
`2026-07-30-pay-links-design.md` (link machinery, admin surface) and
`2026-07-30-buyer-protection-design.md` (platform-held money, completion
feeds the protection pipeline).

## Purpose

Susu — small, regular contributions toward a goal — is how West African
market saving already works. Susu lay-away applies it to goods: the buyer
commits to a product, pays in MoMo chunks over weeks, and the goods release
when fully paid. It converts higher-ticket items (appliances, occasion
fabrics, phones) for buyers with irregular income, with **zero credit risk**
— no underwriting, no arrears; the worst case is always a full refund. Held
balances are float. The trust pitch in one sentence: *your money is always
yours until you own the thing.*

## Decisions (agreed during brainstorm)

1. **Initiation: merchant-created susu links** (a pay-link variant shared in
   the DM); the buyer's first installment activates the plan. Storefront
   "pay small-small" PDP entry is future work.
2. **Terms: flexible amounts + deadline.** Merchant sets total, completion
   deadline, and a minimum chunk (default GH₵10). The buyer pays any amount
   ≥ minimum, whenever — no schedule engine, no missed-payment states,
   matching how susu flexes around market income. Weekly reminders nudge.
3. **Stall policy: auto-refund in full at deadline.** Merchant may extend
   the deadline (forward only) while the plan is active. No forfeit fees —
   "you can always get your money back" is the product.
4. **Stock: reserved at first installment.** The lay-away promise is that
   the goods are set aside; "sold out" after weeks of saving is the worst
   possible outcome. Released on expiry/cancel, converted at completion.
   Mirrors the suppliers-domain `InventoryReservation` pattern.

## Architecture: order-at-completion

Candidates considered: (A) a `SusuPlan` owns contributions and the real
order is created only at completion; (B) a `:layaway`-status order created
upfront; (C) a stored-value wallet. **A chosen.** B leaks a half-real order
state into every load-bearing surface (dashboards, reports, notifications,
stock timing); C is regulatory-adjacent stored value. A matches the
protection-hold philosophy: platform-held money lives outside the order
rails until the purchase is real.

The retroactive stamp is the key move: `Payment.order_id` becomes nullable
and payments gain `susu_plan_id`. Installments are ordinary gateway charges
**with no merchant share** (money sits in the platform account, exactly like
protection holds), attached to the plan. On completion the order is created
via `CheckoutService` and every contribution is stamped with the new
`order_id` — downstream, the result is indistinguishable from an ordinary
fully-paid order with a payment history. Nothing downstream learns susu
exists.

## Domain model

### New resource: `Emakola.Orders.SusuPlan`

Tenant-scoped; the susu-link flavor of the pay-link shape.

| Attribute | Type | Notes |
|---|---|---|
| `code` | string, unique | public link identifier, pay-link format |
| `type` | `:catalog \| :custom` | |
| `variant_id`, `quantity` | uuid, integer | catalog; quantity merchant-set at creation |
| `title` | string | custom plans |
| `total_amount` | integer minor units | snapshotted at creation; price changes never drift the deal |
| `min_chunk` | integer minor units | default 1_000 (GH₵10); stops applying when `remaining < min_chunk` |
| `deadline` | utc_datetime | merchant-extendable, forward only, while `:active` |
| `fee_rate_bps` | integer | snapshot at creation; fee taken **once, on the completed total** |
| `collect_delivery` | boolean | details collected at activation, editable until completion |
| `status` | `:pending → :active → :completed \| :expired \| :cancelled` | |
| `customer_id` | uuid | set at activation (phone find-or-create, as pay links) |
| `contributed_amount` | integer | maintained under the plan-row claim |
| `note`, `created_by_user_id`, timestamps | | as pay links |

### Changes to existing pieces

- **`Emakola.Payments.Payment`** — `order_id` becomes nullable; gains
  `susu_plan_id`. A validation requires exactly one parent (order or plan).
- **Pay-links admin page** — susu links appear as a third link type with
  plan-progress columns (cross-referenced in the pay-links spec).
- **Inventory views** — reserved units visible to the merchant.

### Concurrency rule: one pending chunk at a time

Chunk initiation takes a `FOR UPDATE` claim on the plan row: no new chunk
while one is in flight, amounts capped at `remaining`, final chunk
auto-capped to land exactly on the total. This kills overpay and
double-final-chunk races at initiation instead of refunding excesses after
the fact. Completion fires exactly once, under the same claim.

## Flows

**Buyer.** Opens the susu link → item, total, deadline, min chunk → pays the
first installment → plan activates, stock reserves (catalog plans; custom plans
have no stock to hold). They receive a
**signed "My susu" progress link** (Phoenix.Token, same authority model as
Buyer Protection's tracking link) by SMS/WhatsApp: progress bar, amount
field, pay button, delivery details, and a **cancel button — full refund,
anytime**.

**Completion.** Final chunk lands → order created with details on file →
if the store has Buyer Protection enabled, the order enters a
`ProtectionHold` on the **total** at the snapshotted fee; otherwise the
merchant's net becomes payout-eligible immediately.

**Expiry/cancel.** An Oban sweep expires overdue plans. Expiry, buyer
cancel, and merchant cancel all converge on one path: refund **every
contribution in full** through the existing `RefundService` per contribution
(inheriting its no-blind-retry POST semantics), release the reservation,
notify both parties.

**Notifications** (existing dispatcher): activation + per-chunk receipts
with progress, weekly nudge, deadline warnings at 7 days and 1 day,
completion, expiry-with-refund confirmation; merchant notified at
activation, completion, expiry.

## Edge cases

| Case | Behavior |
|---|---|
| Product taken down mid-plan (moderation/archive) | Auto-cancel + full refund + notify both. A buyer never keeps paying toward a product that can't ship. |
| Price change mid-plan | Irrelevant — `total_amount` snapshotted at creation. |
| Store suspended mid-plan | Chunk initiation pauses (unavailable page). Deadline passing while paused → normal expiry auto-refund (the safe default is the buyer gets the money back). Archived/blocked store → immediate auto-cancel + refund. |
| Chunk in flight when the expiry sweep runs | Sweep **skips** plans with a pending chunk, re-sweeps next run. A chunk confirming against a non-active plan is auto-refunded. |
| Contribution refund fails during expiry | Per-contribution `RefundService` semantics; failures surface in the existing refund ops views; the plan stays visibly unsettled until all refunds confirm. |
| `remaining < min_chunk` | Minimum stops applying; final chunk is exactly the remainder. |
| Buyer loses the signed link | Every notification re-includes it; resend flow on the public page sends to the phone on file (always claims success — no enumeration). |
| Authority | Public code page: view + start only. Signed buyer link: pay, edit delivery, cancel. Merchant admin: cancel, extend. Bare code never moves or reclaims money after activation. |

## Testing

Beyond standard resource/tenancy/LiveView/notification coverage:

- **Concurrency**: `contributed_amount` integrity under simultaneous webhook
  confirmations; one-pending-chunk enforcement; final-chunk auto-cap;
  completion fires exactly once.
- **Order stamping**: completion creates the order, contributions stamped
  with `order_id`, order reads downstream as ordinary and fully paid;
  protection-on routes the total into a hold; protection-off → net
  payout-eligible; fee once, at the snapshotted rate.
- **Reservation**: created at activation, demonstrably blocks storefront
  overselling of reserved units, released on expiry/cancel, converted at
  completion.
- **Expiry sweep**: idempotent re-runs, in-flight-chunk skip,
  late-confirming chunk refunded, every contribution refunded in full.
- **Lifecycle guards**: takedown auto-cancel, suspension pause, extension
  forward-only.
- **Authority**: bare-code page cannot pay/cancel/edit after activation;
  signed link can.
- **Payment parent validation**: exactly one of order/plan; nullable
  `order_id` regression guard across payment queries.

## Out of scope (v1)

- Fixed schedules and arrears logic; forfeit fees.
- Storefront "pay small-small" PDP entry across themes.
- Multi-payer family contributions (culturally real — deliberate future
  idea: relatives chipping into one plan).
- Partial refunds (always full); plan transfer between buyers; interest or
  completion bonuses.

## Success criteria

1. Test coverage above green; `mix format` / `credo --strict` clean.
2. End-to-end: create susu link → first chunk activates + reserves →
   flexible chunks accumulate → completion creates a fully-paid order that
   enters protection (toggle on) or payout eligibility (toggle off).
3. Expiry and both cancel paths refund every pesewa, release stock, and
   notify both sides.
4. A plan's terms (total, fee rate) are provably immune to mid-plan price
   and fee changes.
5. Post-launch: first real completed plan; plan-funnel telemetry
   (created → activated → completed/expired) visible to the merchant.
