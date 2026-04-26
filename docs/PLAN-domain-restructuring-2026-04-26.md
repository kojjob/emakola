# Domain Restructuring Plan

**Date:** 2026-04-26
**Author:** Claude (audit-driven plan)
**Status:** Proposed — needs review before execution

This document sequences three structural changes to bring the Ash
domain layout in line with the project's bounded-context boundaries
documented in `CLAUDE.md`:

1. **Extract `Store` from `Accounts` into a new `Stores` domain**
2. **Create an `Inventory` domain** (currently inventory is a single
   `stock_quantity` field on `Catalog.Variant`)
3. **Extract `Coupon` from `Orders` into a new `Marketing` context**

Each is a multi-day refactor with a wide blast radius. They are
**sequenced** because they depend on each other: domain extraction
needs stable APIs, and we don't want to be moving the goalposts on
two callers at once.

---

## Why this matters

`CLAUDE.md` declares these bounded contexts:

> - `Emakola.Catalog` — Products, Variants, Categories, Collections
> - `Emakola.Orders` — Orders, LineItems, Fulfillments
> - `Emakola.Payments` — Payments, Refunds, Transactions
> - `Emakola.Stores` — Stores, StoreSettings, Domains
> - `Emakola.Accounts` — Users (merchants), authentication
> - `Emakola.Inventory` — Stock levels, locations
> - `Emakola.Marketing` — (implicit — Coupons, discounts)

Today's reality:

- `Store` lives in `Accounts` (~33 call sites depend on
  `Emakola.Accounts.Store`)
- `Inventory` is a column on `Catalog.Variant` plus an `Inventory.Workers`
  directory holding only the low-stock-alert worker
- `Coupon` lives in `Orders` (5 call sites) — the wrong context, since
  coupons are a marketing/growth concept, not a transactional one

The drift is mild today, but every new feature in these areas (e.g.
multi-warehouse inventory, store-level subdomains, customer-segment
marketing campaigns) will be harder until the boundaries are right.

---

## Sequencing

### Step 1: Extract `Coupon` to `Marketing` (smallest, fewest blockers)

**Why first:** 5 call sites. Limited surface. No cross-domain identity
relationships (Coupon belongs to Store, used by Order — but Coupon
itself doesn't reference Store/Order in ways that block the move).

**Steps:**

1. Create `lib/emakola/marketing/marketing.ex` (Ash domain).
2. Move `lib/emakola/orders/resources/coupon.ex` →
   `lib/emakola/marketing/resources/coupon.ex`.
3. Update module name `Emakola.Orders.Coupon` → `Emakola.Marketing.Coupon`.
4. Update `Emakola.Orders` domain: remove `Coupon` resource block.
5. Update `Emakola.Marketing` domain: register `Coupon` with `define`
   for `list_coupons_by_store`, `list_active_public_coupons`,
   `find_coupon_by_code`, `create_coupon`, `update_coupon`,
   `deactivate_coupon`, `increment_coupon_usage`.
6. Update 5 call sites (grep `Emakola.Orders.Coupon` and
   `Emakola.Orders.list_coupons_by_store|find_coupon_by_code|...`):
   - `lib/emakola/orders/checkout_service.ex`
   - `lib/emakola_web/live/admin/coupon_live.ex`
   - `lib/emakola_web/live/storefront/checkout_live.ex` (apply_coupon)
   - any tests that reference these
7. The `orders.coupon_id` FK in DB stays — it's just the resource
   module that moves. No migration needed.
8. Tests: `mix test` — domain-aware assertions might need updating.

**Estimated risk:** Low. **Estimated effort:** 2–3 hours.

**Watch out for:** the existing `bypass action_type(:create)` /
ActorHasStoreAccess policy structure should carry through verbatim.

---

### Step 2: Create `Inventory` domain + extract stock fields

**Why second:** Inventory's identity is tightly coupled to `Catalog.Variant`
right now — a single `stock_quantity` integer + `track_inventory` flag.
Extracting cleanly requires introducing a separate `StockLevel` resource
keyed on `(variant_id, location_id)` (where today there's no location).

**Two-phase approach** so no single PR is destabilising:

**Phase 2a: Create the domain shell with no migration**
1. Create `lib/emakola/inventory/inventory.ex` (Ash domain).
2. Create `lib/emakola/inventory/resources/stock_level.ex` — Ash resource
   pointing at the *existing* `variants` table with attributes for
   `variant_id` (read-only, sourced from variant.id) and
   `quantity`/`track_inventory` (calculated, sourced from
   `variant.stock_quantity` / `variant.track_inventory`).
3. Add a single read action `get_for_variant(variant_id)` returning the
   current stock state.
4. Wire the `Emakola.Inventory.Workers.LowStockAlertWorker` (already in
   place) and any inventory-page LiveView to use the new resource for
   reads, but writes still flow through `Catalog.Variant`.

This phase **adds** without changing existing behaviour. If we stop
here, we have: a clean read API for inventory + a place for future
multi-location work.

**Phase 2b: Real schema migration (optional, future)**
1. New table `stock_levels(id, variant_id, location_id, quantity,
   track_inventory)`.
2. Backfill from `variants.stock_quantity`.
3. Update CheckoutService to decrement `stock_levels.quantity` instead
   of `variants.stock_quantity` (transactional).
4. Drop columns from `variants` (after several deploys + monitoring).

Phase 2b is large and risky. **Don't do it until multi-location is a
concrete product requirement.**

**Estimated risk for 2a only:** Medium. **Effort:** 1 day.

---

### Step 3: Extract `Store` to its own domain

**Why last:** highest blast radius. ~33 call sites. Changes the
multi-tenant anchor itself.

**Steps:**

1. Create `lib/emakola/stores/stores.ex` (Ash domain).
2. Move `lib/emakola/accounts/resources/store.ex` →
   `lib/emakola/stores/resources/store.ex`.
3. Module rename `Emakola.Accounts.Store` → `Emakola.Stores.Store`.
4. `StoreMembership` (`lib/emakola/accounts/resources/store_membership.ex`)
   stays in `Accounts` because it's the merchant↔store membership
   bridge — but its `belongs_to :store` updates the destination module.
5. `Emakola.Policies.Checks.ActorHasStoreAccess` — update the special
   case at line ~40 (`if changeset.resource == Emakola.Accounts.Store`).
6. Update 33 call sites with grep+sed:
   - All controllers/plugs/LV mounts/storefront resolver
   - Factory `create_store!` / `create_merchant_with_store!`
   - All resources with `belongs_to :store, Emakola.Accounts.Store`
     across catalog/orders/payments/customers/shipping/notifications/etc.
7. **Tests will break broadly.** Run `mix test` per call-site batch,
   not all at once.
8. Update CLAUDE.md domain map example.

**Estimated risk:** High. **Effort:** 1–2 days.

**Watch out for:**
- AshAuthentication `Merchant` resource declares
  `relationships do has_many :store_memberships ... has_many :stores end`.
  These need updating.
- The `multitenancy strategy: :attribute, attribute: :store_id` blocks
  on customer/order/payment/etc. resources reference `store_id` as a
  UUID — they don't reference the Store module directly, so they're
  unaffected.
- The DB table is still called `stores`. Ash `postgres do table("stores")`
  block doesn't change. No migration needed.

---

## Migration test plan

After each step:

1. `mix compile --warnings-as-errors`
2. `mix format --check-formatted`
3. `mix credo --strict`
4. `mix test --trace --max-failures 5`
5. Manual smoke: open admin, list products, view a coupon, list
   customers, place a test order, mark shipped.

After **all three** steps:

1. Full `mix test` (1946 tests baseline).
2. Run `mix xref graph --label=compile-connected --format=stats` —
   the cross-domain edge count should *drop*, not climb.
3. `iex -S mix` — try common queries against each new domain
   namespace.

---

## Out of scope for this plan

- Renaming database tables (e.g., `coupons` → `marketing_coupons`) — not
  worth the disruption.
- Breaking the public API: `Emakola.Orders.list_coupons_by_store/1`
  callers will need to migrate to `Emakola.Marketing.list_coupons_by_store/1`,
  but we shouldn't keep deprecation shims — small enough to fix at
  call sites in one pass.
- Any change to multi-tenant policies — the `multitenancy` blocks
  declared in commit 05a2cb9 stay verbatim; only the module *namespace*
  moves.

---

## Decision required

Three questions for the human reviewer:

1. **Approve sequencing?** Coupon → Inventory shell → Store?
2. **Phase 2b (real stock migration) — wait or do?** Recommend wait
   until multi-location is on the roadmap.
3. **Rename `Accounts` to something else** when Store leaves it?
   `Accounts` would then hold User/Merchant/Organisation/StoreMembership
   only. Could rename to `Identity`. Optional, separate decision.
