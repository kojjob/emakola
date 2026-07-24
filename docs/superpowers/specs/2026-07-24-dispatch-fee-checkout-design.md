# Dispatch Fees at Checkout — Design

**Date:** 2026-07-24
**Status:** Approved
**Owner ask:** Supplier per-area dispatch fees become real money — charged to
the customer at checkout and settled 100% to the supplier through the splits
engine. Final sub-project of the supplier-marketplace sequence.

## Context (verified by code exploration, 2026-07-24)

- Customer totals today: `total = subtotal + delivery_fee - discount`
  (`checkout_service.ex:248-287`); `delivery_fee` comes from the MERCHANT's
  own `DeliveryZone` (`checkout_live.ex:633-659`) and is credited 100% to the
  `:dropshipper` split (`order_settlement.ex:36-39`). Suppliers ship dropship
  items but receive none of it.
- The checkout region selector is a stale 7-key snake_case `<select>`
  (`themes/default_renderers/checkout.ex:284-297`) matched fuzzily to
  `DeliveryZone.name` (`shipping.ex:59-70`); `SupplierOffer.dispatch_fees`
  keys are the canonical 16 title-case `GhanaRegions`.
- `dispatch_fees` is display-only today — read nowhere in checkout,
  LineItem, PaymentSplit, or settlement.
- Splits: `SplitCalculator.calculate/2` — `:wholesaler` = Σ cost×qty per
  supplier; `:platform` = bps of margin; `:dropshipper` = remaining margin +
  delivery_fee − discount. `Σ splits == payment.amount` is enforced ONLY by
  construction + tests (no DB constraint). `unique_allocation` identity
  guards double-recording. `Fulfillment` is per-supplier per-order and
  carries no money field.
- LineItem prices snapshot at order creation (`denormalize_variant.ex`);
  reseller `Variant.cost_price` is stale-but-mutable between syncs.

Decisions locked with Kojo (2026-07-24):

1. **Stack both fees** — customer pays the merchant's delivery fee (dropshipper
   keeps it, unchanged) PLUS each supplier's dispatch fee (passed to that
   supplier).
2. **Unquoted region → charge 0** — checkout proceeds, supplier absorbs;
   incentive to quote all regions. "Other" region → always 0.
3. **100% pass-through** — no platform cut on dispatch fees; platform fee
   stays on margin only.
4. **Max per supplier** — one supplier ships one parcel per order: charge the
   highest applicable fee across that supplier's offers in the cart, once.

## 1. Region alignment (prerequisite)

The checkout region `<select>` upgrades to the canonical 16
`Emakola.Suppliers.GhanaRegions` + `"Other"`. Option values use snake_case
parameters (e.g., `"greater_accra"`, `"western_north"`); `GhanaRegions.from_param/1`
canonicalizes them to the label (e.g., `"Greater Accra"`) for `dispatch_fees`
lookup. The fuzzy `Shipping.find_zone/2` match keeps existing merchant
`DeliveryZone` rows working (case/underscore-insensitive — verified). Any
theme/renderer that duplicates the region list gets the same source-of-truth
constant via `GhanaRegions.select_options()` (grep for the old 7-key list
across `lib/emakola/themes/`).

## 2. Fee computation & snapshot

At checkout (inside `CheckoutService.run_checkout`'s transaction, where cart
items are already grouped by `supplier_id` for fulfillments):

- For each dropship supplier group: resolve each line's `SupplierOffer` via
  its reseller listing (listing → offer), read `offer.dispatch_fees[region]`
  (canonical string; missing key or "Other" → 0), and set the group's fee to
  the MAX across the group's offers.
- **Snapshot**: new `dispatch_fee :: integer` (pesewas, `null: false,
  default: 0`) on `Fulfillment` — written at fulfillment creation. New
  `dispatch_fee_total :: integer` (pesewas, `null: false, default: 0`) on
  `Order` = Σ fulfillment fees, written in the same transaction.
- **Total math**: `total = subtotal + delivery_fee + dispatch_fee_total −
  discount_amount`. Coupons/discounts continue to apply to merchandise, not
  to dispatch fees (discount math unchanged).
- Later edits to the offer's `dispatch_fees` never affect existing orders —
  settlement reads the snapshots only.
- Hand-written migrations (`ash.codegen` unusable), reversible.

## 3. Splits

`SplitCalculator.calculate/2` (dropship path only):

- Each `:wholesaler` share += its fulfillment's snapshotted `dispatch_fee`
  (100% pass-through; keyed by the same `supplier_id` grouping).
- `:platform` unchanged — bps of MARGIN only (margin excludes dispatch fees
  by definition: retail − cost).
- `:dropshipper` unchanged — remaining margin + delivery_fee − discount.
- Sum invariant holds by construction: the total grew by exactly
  Σ dispatch fees, and wholesaler shares grew by the same amount. No new
  split role; no changes to `mark_settled`, webhook handling, or
  reconciliation; the `unique_allocation` identity is untouched.
- Non-dropship orders: `dispatch_fee_total` is always 0; the platform-fee
  path (`PlatformFee.calculate/2` on `order.total`) is numerically unchanged
  for them. NOTE: for MIXED/dropship orders no behavior change to the
  platform-fee base either — platform fee is margin-bps in the dropship
  path, which never includes dispatch fees.

## 4. Checkout UI

- Totals box gains one line — "Supplier dispatch" — shown only when
  `dispatch_fee_total > 0`, summed across suppliers (no per-supplier
  breakdown in v1). The existing "Delivery" line is unchanged.
- The fee recomputes when the customer changes region (same event that
  recomputes the merchant delivery fee today).
- Order confirmation page/emails show the same line when > 0 (only where
  totals are already itemized — mirror the delivery-fee line's presence).

## 5. Failure & edge semantics

- Supplier with cart items but no quoted fee for the region: fee 0 (locked
  decision) — no error, no log spam (this is a normal state).
- A cart line whose reseller listing/offer can no longer be resolved at
  checkout: fee 0 for that line's contribution (the item itself still sells
  — listing-pause enforcement is out of scope here and unchanged).
- Multi-supplier carts: fees compose per supplier; the existing
  all-suppliers-verified gate for gateway splits is unchanged (fees ride
  inside wholesaler shares, so the manual-ledger fallback also carries them
  via the same share amounts).

## 6. Testing (TDD, tests first)

Unit (fee computation):
- Max-per-supplier across multiple offers; single offer; unquoted region → 0;
  "Other" → 0; multi-supplier composition; merchant-owned lines contribute
  nothing.

Settlement (sum invariants, the critical suite — mirror
`order_settlement_test`'s style):
- Dropship order with fee: `Σ splits == payment.amount`; wholesaler share ==
  cost + dispatch fee; platform fee base unchanged (margin only);
  dropshipper share unchanged vs a fee-less equivalent order.
- Multi-supplier with different fees; with a coupon discount; fee 0 order
  is byte-identical to today's math.

Snapshot:
- Changing the offer's `dispatch_fees` after order creation does not change
  the order's fulfillment fee, order total, or split amounts.

LiveView:
- Region select offers the 16 canonical regions + Other; changing region
  updates the "Supplier dispatch" line; line hidden when 0; end-to-end
  checkout charges `subtotal + delivery + dispatch − discount`.

Seal:
- Full checkout through the real UI → fulfillment rows carry snapshots →
  `OrderSettlement.prepare` output carries the fee in the wholesaler share.

## Out of scope (follow-ups)

- Refund treatment of dispatch fees (refund paths are item-scoped today;
  dispatch-fee refunds need their own design).
- Per-supplier breakdown in the checkout totals UI; supplier fee analytics.
- Requester-side invite throttle (already tracked in LAUNCH_TODO).
- Supplier-side delivery-zone concept replacing region-keyed fees.
