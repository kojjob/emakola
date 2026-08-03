# Supplier Stock Truth Cycle — Design

**Date:** 2026-08-03 · **Status:** Approved by Kojo · **Branch:** `feature/supplier-stock-truth` off main `83936940`

## Problem

A reseller's dropship listing reflects supplier stock only as an **import-time
snapshot**: `available = source.available and in_stock?(source)` is computed
once (`listing_importer.ex` `create_variant!`) and never again. The three-layer
gap, confirmed by trace on 2026-08-03:

1. `ListingImporter.sync/2` recomputes availability from live supplier stock
   but has **zero production callers** (tests only). A supplier that sells out
   leaves every reseller listing sellable forever.
2. Dropship variants are `track_inventory: false`
   (`Catalog.Changes.UntrackDropshippedInventory`), and
   `Orders.Changes.DecrementStock` skips untracked variants — a network sale
   **never decrements the supplier's source variant** (except through
   passport-tier reservation consumption). The supplier's own counts ignore all
   network sales, so ten resellers can sell the same last unit simultaneously.
3. No stock signal exists anywhere in the reseller-facing UI (supply catalog,
   network page, listings tab show price/margin/connection only).

Hard cutoffs DO propagate today (offer pause/retire and connection severance →
`pause_offer_listings!` / `pause_connection_listings!`), and checkout honours
`available: false` on supplier-linked variants
(`checkout_service.ex` `available_for_order?/2`). Those paths are kept as-is.

## Fix order (binding)

Decrement first (makes supplier counts TRUE), then sync (propagates), then UI
(shows). Wiring sync before decrement would propagate a number that is already
wrong. Layers are separately shippable in this order; each layer's tests stand
alone.

## Layer 1 — Network sales decrement supplier stock (the truth-maker)

**New module** `Emakola.Suppliers.NetworkStock` with
`decrement_for_order(order_id, store_id)`, called from **both** webhook
handlers immediately AFTER `InventoryReservations.consume_for_order/2`:

- `paystack_webhook_handler.ex:244` (charge.success confirm path)
- `hubtel_webhook.ex:69`

Both handlers get one added line; all logic lives in the module.

**Per supplier-linked line item** of the confirmed order:

1. Map `line_item.variant_id` → `ResellerListingVariant`
   (`reseller_variant_id == variant_id`) → `offer_variant` →
   `source_variant_id`. **No mapping → skip** (manually-created supplier links
   are off-platform suppliers; there is nothing on-platform to decrement).
2. Compute the shortfall: `line_item.quantity − Σ
   InventoryReservationConsumption.quantity where line_item_id ==
   line_item.id`. Reservation-covered units were physically removed from
   supplier stock at reserve time (`InventoryReservations.reserve/4` funnels
   through `Inventory.adjust`) — decrementing them again would double-count.
   Shortfall ≤ 0 → skip. This runs after `consume_for_order`, so consumption
   rows for this order are final.
3. In ONE transaction per source variant: lock the source variant
   (`FOR UPDATE`), **idempotency guard** — skip if a `StockMovement` with
   `reason: :network_sale` already exists for `(source_variant_id, order_id)`
   (webhook redelivery re-enters here; `consume_for_order` is already
   idempotent by its own consumption-row check), then decrement by
   `min(shortfall, max(source.stock_quantity, 0))` — **clamp, never negative,
   never raise**. Funnel through the Inventory domain against the supplier's
   default location so `total == sum(levels)` holds and the movement ledger
   records `:network_sale` with the order id. A clamped (partial or zero)
   decrement logs a warning naming order, variant, and shortfall — the paid
   order stands for manual fulfilment, mirroring the existing oversell
   contract in `DecrementStock` (`after_transaction`, log-and-stand).
4. Only decrement when the source variant has `track_inventory: true`
   (untracked supplier stock has no number to maintain).

`StockMovement.reason` gains `:network_sale` (verify at implementation whether
the attribute is a constrained atom list needing a code-only change or a DB
enum needing a migration; repo convention: hand-written migrations —
`mix ash.codegen` is broken repo-wide).

**Failure isolation:** `decrement_for_order` returns `:ok` always; any
internal error is rescued and logged (`[NetworkStock]` prefix). It must be
impossible for this call to fail payment webhook processing — same discipline
as the `:earnings_accrued` dispatch and `consume_for_order`.

## Layer 2 — Stock changes propagate (the messenger)

**Choke point:** every stock path — `Inventory.adjust`,
`Inventory.decrement_for_sale!`, Layer 1's decrement, CSV import, manual
admin edits — lands as an Ash update on `Catalog.Variant.stock_quantity`.
Add an after-action hook on Variant update actions that fires **only when
`stock_quantity`, `available`, or `track_inventory` actually changed**, and
enqueues `Emakola.Suppliers.Workers.SupplierStockSyncWorker` with the variant
id. Oban `unique` on `[args: [:variant_id]]` with a short period (60s)
debounces bursts; the worker recomputes from CURRENT state, not an event
payload, so last-write-wins is correct under coalescing.

**Worker logic** (idempotent, cheap no-op first):

1. `SupplierOfferVariant` where `source_variant_id == variant_id` — none →
   done (this is the common case for every non-supplier store; the lookup must
   be indexed).
2. For each mapped offer variant → `ResellerListingVariant` rows → parent
   `ResellerListing` with `status == :active` (paused/retired listings stay
   paused; reactivation is the existing import/offer lifecycle's job) → update
   each `reseller_variant` toward
   `target = source.available and Emakola.Catalog.Variant.in_stock?(source)`.
   Skip writes when the value is unchanged. Cross-tenant writes use
   `authorize?: false` (system actor), matching `pause_offer_listings!`.
3. Both directions, respecting reseller intent (**Kojo ruling 2026-08-03,
   amending the original unconditional formula**): sell-out flips listings
   off AND stamps `supplier_sync_paused_at` on the reseller variant; restock
   re-enables ONLY variants carrying that marker (sync-caused off) and clears
   it. A reseller's own manual `available: false` (marker nil) sticks until
   the reseller re-enables it; any manual toggle of `available` clears the
   marker (the merchant reclaims ownership). The worker writes through a
   dedicated `:sync_availability` variant action; manual paths clear the
   marker on `:available` change.

Availability-only propagation — deliberately NOT wiring full
`ListingImporter.sync/2` (it also overwrites title/description/price); that
stays a separate product decision.

## Layer 3 — Resellers see it (the face)

Supplier-stock **status badge** — `In stock / Low stock / Out of stock` —
**status only, never the supplier's raw quantity** (that is the supplier's
private business data). Derived from source variants via
`Emakola.Inventory.stock_status/1`:

- Offer-level aggregation: all source variants `:out` → **Out of stock**; any
  `:low` (and not all out) → **Low stock**; else **In stock**.
- Surfaces: supply-network browse offer cards (`supply_network_live.ex`
  offers tab), supply-catalog offer page (`supply_catalog_live/show.ex`),
  and the reseller's imported-listings tab (`hustle_listings`, per-listing
  badge via the same aggregation over mapped source variants).
- Loaded async with the page's existing data loads (batch the source-variant
  reads — no N+1); the synced flag (Layer 2) is the enforcement, the badge is
  the visibility. Follow the Makola Admin design language (severity-pill
  style); load `frontend-design` before markup.

## Layer 0 — Checkout checks live (bonus, cheap)

`CheckoutService` stock validation: for a supplier-linked variant WITH a
`ResellerListingVariant` mapping, also load the live source variant and
require `Emakola.Catalog.Variant.in_stock?(source, quantity)` — catching
"customer wants 5, supplier has 2", which the boolean flag cannot express.
Unmapped (off-platform) supplier variants keep today's flag-only behaviour.
One batched read for the cart's mapped variants — no per-item queries. On
failure the existing `:insufficient_stock` contract fires ("Some items are
out of stock").

## Out of scope (YAGNI, named)

- Full `sync/2` wiring (title/description/price overwrite) — separate product
  decision.
- Supplier oversell SMS/notification — clamp + log + auto-pause covers it;
  revisit if ops sees clamped decrements in practice.
- Susu-on-dropship stock interplay — `SusuStock` pre-decrements tracked
  variants only today; unchanged.
- Reseller-facing raw quantities, backorder states, supplier stock editing
  from the network UI.
- Retroactive decrement/backfill for historical network orders.

## Test requirements (per layer)

- **L1:** decrement fires exactly once under webhook replay (redeliver the
  same charge.success — movement count stays 1); reservation-covered units
  never double-decrement (reserve 2, buy 3 → source decrements exactly 1);
  clamp at zero never raises and the confirm/settlement flow completes;
  unmapped supplier variant → no-op; supplier `total == sum(levels)` invariant
  holds after network decrement; both webhook handlers covered.
- **L2:** supplier sell-out flips reseller variant `available` false across
  tenants; restock flips back ONLY sync-paused variants (manual off sticks;
  marker cleared on manual toggle); paused listing stays paused through a
  restock; hook does NOT enqueue on unrelated variant updates (e.g. price);
  Oban uniqueness asserted via `all_enqueued` count (unique-conflict returns
  the attempted job — assert counts, not ids).
- **L3:** badge renders each of the three states from seeded source stock;
  raw quantity never appears in reseller-facing markup; no N+1 (single batched
  source read per page).
- **L0:** cart quantity above live supplier stock → `:insufficient_stock`;
  flag-available but source-empty variant blocked at checkout.
- Full suite green; `mix format --check-formatted`; `mix credo --strict`;
  parse the `Result:` line (exit codes lie when piping).

## Constraints (binding, inherited)

- The payment webhook path must never fail or reorder because of stock logic —
  observer/appendix discipline, rescue-and-log.
- Tenant isolation: cross-store reads/writes only through the mapping chain,
  `authorize?: false` system paths, mirroring existing suppliers-domain code.
- Money amounts untouched — this initiative moves stock, not money. Zero
  changes to splits/settlement/payout code.
- PR-1 tripwire (standing): no mutation path touching flagged splits.
- TDD; hand-written migrations if any; house SMS/notification rail untouched.
