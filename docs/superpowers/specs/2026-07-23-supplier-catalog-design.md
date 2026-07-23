# Supplier Product Catalog for Merchants — Design

**Date:** 2026-07-23
**Status:** Approved
**Owner ask:** Registered merchants should be able to see suppliers' products with
details — price, cost of dispatch, and all relevant info — and choose from them.

## Context

The dropshipping engine already exists: `SupplierOffer` + `SupplierOfferVariant`
(wholesale/suggested/max pricing in pesewas), `SupplyConnection` (merchant ↔
wholesaler), `Offers.list_available/2` (connected wholesalers only), and
`ListingImporter.import/4` (clones an offer into the merchant's store as a
reseller listing). The only merchant-facing surface is the cramped "Earn
catalog" section inside the 3,223-line `SupplyNetworkLive`.

Gaps this feature closes:

1. **No dispatch-cost concept exists anywhere in the domain.**
2. Merchants can only see offers from wholesalers they are *already* connected
   to — they must connect blind.
3. No browse/detail experience worthy of a purchasing decision.

Decisions locked with Kojo:

- **Discovery:** browse ALL published offers; wholesale pricing gated behind an
  approved connection ("all offers, details gated").
- **Dispatch cost:** fee **per delivery area**, supplier-set.
- **UI:** new dedicated pages, not more god-module growth.

## 1. Data model

`SupplierOffer` gains:

- `dispatch_fees :: :map`, `allow_nil?: false`, default `%{}`.
  Keys: delivery-area strings (must be a subset of `delivery_areas`).
  Values: non-negative integer **pesewas**.
  Example: `%{"Accra" => 1500, "Kumasi" => 2500}`.
- New Ash validation module `Emakola.Suppliers.Validations.DispatchFees`
  enforcing value type/sign and key ⊆ `delivery_areas`.
- Accepted on the existing `create` and `update_terms` actions.
- Hand-written migration (`ash.codegen` snapshots are stale — see LAUNCH_TODO):
  `add :dispatch_fees, :map, null: false, default: %{}`.
- Display rule: an area listed in `delivery_areas` with no fee entry renders
  "— (ask supplier)".

## 2. Domain API (`Emakola.Suppliers.Offers`)

- `list_discoverable(actor, store_id)` →
  `{:ok, [%{offer: offer, connected?: boolean}]}`
  All `:published` offers passing the existing `discoverable?/1` filter,
  **excluding the store's own offers**, sorted `published_at: :desc`,
  query-limited to 200. Loads: `wholesaler_store`, `source_product: :images`,
  `offer_variants: :source_variant`. One extra query fetches the store's
  active-connection wholesaler ids to compute `connected?`.
- `get_discoverable(actor, store_id, offer_id)` →
  `{:ok, %{offer: offer, connection_status: status}}` where
  `status ∈ :connected | :pending | :none`; `{:error, :not_found}`
  when unpublished/undiscoverable/own offer.
- Both use the service's existing `ensure_access/2` actor check.

## 3. UI

Two new LiveViews under the merchant admin (same auth/live_session as existing
admin pages). New sidebar entry "Supplier catalog".

### Index — `/admin/supply/catalog`

Responsive card grid. Per card: first product image, product title, supplier
store name, delivery-area chips, dispatch-fee range (e.g. "GH₵ 15–25
dispatch"; "Dispatch —" when no fees are quoted yet), suggested-retail range
across variants, and a "Connected" badge or lock glyph. In-memory search over product title + supplier name (catalog is
small today; the 200-row query cap is stated in code as the scaling boundary).

### Show — `/admin/supply/catalog/:offer_id`

- Image gallery from the source product.
- Supplier panel: store name, connection state.
- **Variants table:** per variant — label, suggested retail (always visible);
  supplier price and margin (GH₵ + %) when `earning_model == :markup`, or
  fixed commission when `:fixed_commission` — rendered ONLY when connected,
  otherwise locked cells (lock icon, no values). `max_retail_price` is also
  connection-gated.
- **Dispatch-fees table:** delivery area → GH₵ fee (always visible).
- **Terms:** supplier `return_terms`, `returns_window_days`,
  `warranty_months`, `warranty_terms`, verbatim, always visible.
- **CTA per connection state:**
  - `:connected` → "Add to my store" → existing `ListingImporter.import/3`.
  - `:none` → "Request connection" → existing `Network.request/2`.
  - `:pending` → disabled "Request sent".

Both mounts are gated with `connected?/1` + a loading shell (no SEO surface —
these are auth-only admin pages; same pattern as the merchant dashboard).
Money formatting uses the existing pesewas display helpers. Every button has
an explicit `handle_event` clause (unmatched events crash LiveViews here).

## 4. Gating rules

| Always visible | Connection-gated |
|---|---|
| Product info, images, description | `supplier_price` |
| Supplier store name | Margin math (GH₵ and %) |
| Delivery areas + **dispatch fees** | `fixed_commission_amount` |
| Suggested retail prices | `max_retail_price` |
| Return/warranty terms | "Add to my store" action |

## 5. Error handling

- Offer paused/archived mid-browse: Show redirects to Index with "This offer
  is no longer available."
- Import errors mirror the existing handler: `:listing_exists` → info
  "Already in your store."; other errors → generic failure flash.
- Duplicate/invalid connection request: surface `Network.request/2` error as
  a flash.
- Server-side re-check: `import_offer` re-fetches via `get_discoverable` and
  requires `:connected` — the gate is enforced server-side, not just hidden
  in markup.

## 6. Testing (TDD, tests first)

Unit:
- `dispatch_fees` validation: negative value, non-integer value, key outside
  `delivery_areas` all rejected; valid map accepted; default `%{}`.
- `list_discoverable`: includes published offers from unconnected wholesalers;
  excludes own offers, drafts, and undiscoverable offers; `connected?` flag
  correct per wholesaler.
- `get_discoverable`: three connection states; `:not_found` for paused offer.

LiveView:
- Index renders an unconnected supplier's offer WITHOUT wholesale price.
- Show renders margin cells when connected; locked cells when not.
- "Request connection" creates a pending `SupplyConnection`.
- "Add to my store" creates a `ResellerListing` when connected; is rejected
  server-side when not connected.
- Dispatch fees render per area; missing area fee renders the placeholder.

## Out of scope (follow-ups)

- Supplier-side offer/fee entry UI (`Offers.create_draft/publish/update_terms`
  currently have no web callers at all — offers are seeded/console-created).
- Using per-area dispatch fees in checkout totals/settlement math.
- Pagination beyond the 200-offer query cap.
- Linking the old "Earn catalog" section to these pages / retiring it.
