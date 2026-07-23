# Supplier Offer Management UI — Design

**Date:** 2026-07-23
**Status:** Approved
**Owner ask:** Make the supplier catalog real — any merchant can create, price,
and publish supplier offers (including per-area dispatch fees) without the
console.

## Context

The merchant-facing supplier catalog (PR #341) lets merchants browse and
import published offers, but `Offers.create_draft/add_variant/publish/
update_terms` have **no web callers** — only console-seeded stores can act as
suppliers. Suppliers ARE merchants (same account + store model; roles are
per-connection), so this is one missing form, not a new account type.

Sub-project sequencing locked with Kojo: **this UI first**, then connection
notifications (SMS + WhatsApp + in-app), then charging dispatch fees at
checkout. Small UX items ride along here (see §6).

Decisions locked with Kojo:

- **Both earning models in v1**: markup AND fixed commission (with the
  domain's exact reconciliation rule surfaced in the form).
- Dedicated pages mirroring the catalog pattern (Approach A) — no god-module
  growth.

## 1. Domain additions

`SupplierOfferVariant` (currently read + create only) gains:

- `update :update_terms` — accepts `supplier_price`, `suggested_retail_price`,
  `max_retail_price`, `fixed_commission_amount`.
- `destroy :destroy`.

`Emakola.Suppliers.Offers` gains, following `add_variant/3`'s shape
(`ensure_access/2` on the offer's wholesaler store):

- `update_variant(actor, offer, variant, attrs)`
- `remove_variant(actor, offer, variant)`

Both guarded: allowed only while the offer's status is `:draft` or `:paused`
(`{:error, :offer_not_editable}` otherwise). Published economics are locked —
importers priced against them; the pause → edit → republish path re-runs the
existing `ensure_publishable_variants` economics validation at publish, so bad
edits cannot go live. No other domain changes.

## 2. Index — `/admin/supply/offers` (`Admin.SupplyOffersLive.Index`)

The store's own offers via existing `Offers.list_owned/2`: product title +
first image, earning-model badge, variant count, status pill
(draft/published/paused/archived), created/published date. Per-status actions:

| Status | Actions |
|---|---|
| draft | Edit · Publish · Archive |
| published | Pause · Archive |
| paused | Edit · Republish · Archive |
| archived | (none — terminal) |

Publish/republish surface economics errors as flash. "New offer" CTA.
Empty state explains what offers are and links to the catalog.

## 3. Form — `/admin/supply/offers/new`, `/admin/supply/offers/:id/edit`
(`Admin.SupplyOffersLive.Form`)

- **Product picker**: the store's own products that have ≥1 variant
  (select; disabled with hint when none). Product locked after draft
  creation (offers are 1:1 with a product via the unique identity).
- **Earning model** radio — switches the per-variant pricing table columns:
  - `markup`: Wholesale (GH₵) · Suggested retail · Max retail (optional).
    Live hint: suggested must exceed wholesale.
  - `fixed_commission`: Wholesale · Customer price · Commission. Live hint
    and inline reconciliation: wholesale + commission must equal customer
    price exactly (the domain rejects anything else with
    `:invalid_fixed_commission_terms`).
  - Model locked after draft creation (variants are validated against it).
- **Delivery areas**: checkboxes for the 16 Ghana regions (module constant,
  canonical strings — keeps `dispatch_fees` keys consistent across
  suppliers). Checking a region reveals an optional dispatch-fee input
  (GH₵); blank = no quote (catalog shows "— (ask supplier)"). Unchecking a
  region clears its fee (the validation requires fees ⊆ areas).
- **Terms**: return terms (textarea), returns window days, warranty months,
  warranty terms.
- **Buttons**: "Save draft" (create or update everything, stay) and
  "Publish" (save, then `Offers.publish`; errors — inactive product, no
  available variant, bad economics — render inline/flash without losing
  form state).
- **Restricted edit** (published offers): pricing table read-only with a
  note ("Pricing is locked while the offer is live — pause to edit");
  terms/areas/fees remain editable via `update_terms`.
- Draft/paused edit: full form; variant rows can be priced, re-priced, or
  removed (`update_variant`/`remove_variant`); newly added product variants
  appear as unpriced rows addable via `add_variant`.

## 4. Money & input safety

- Prices entered in GHS decimals, converted to integer pesewas with the same
  parsing helper the product form uses (reuse, don't duplicate; extract to a
  shared helper if it is currently private).
- Every rendered event has an explicit `handle_event`; all handlers guard
  payload shape/types (binary checks before `String.*`, `Integer.parse` for
  numerics) — crafted payloads no-op or flash, never crash (standing policy
  after the catalog fix wave).
- All writes go through the `Offers` service (no `authorize?: false` in the
  web layer).

## 5. Error handling

- `create_draft` unique-product violation (offer already exists for the
  product) → inline error linking to the existing offer's edit page.
- Publish failures map to human copy: `:source_product_not_sellable`,
  `:offer_requires_variants`, `:offer_requires_available_variant`,
  `:invalid_offer_economics` each get a specific flash.
- Edit routes 404-redirect (flash + navigate to the index) for offers not
  owned by the current store or archived.

## 6. Small UX items riding along

- Sidebar: new "My Offers" entry (`active_nav: :supply_offers`); give the
  three supply-related entries distinct icons (Suppliers keeps `truck`;
  Supplier Catalog and My Offers each get a different existing icon from the
  sidebar set — implementer picks unused ones).
- SupplyNetworkLive's Earn-catalog section: one-line banner linking to
  `/admin/supply/catalog` (browse) and `/admin/supply/offers` (manage) — link
  only, no retirement yet.

## 7. Testing (TDD, tests first)

Domain:
- `update_variant`/`remove_variant`: succeed on draft and paused; rejected
  with `:offer_not_editable` on published/archived; rejected for an actor
  without store access; republish after a bad paused edit is blocked by the
  economics validation.

LiveView:
- Renders-without-crashing floor test for BOTH pages (Index and Form).
- Full happy path: create draft (markup) → price variants → select regions +
  fees → publish → offer appears in `Offers.list_discoverable/2` for another
  store (closes the supplier→catalog loop end-to-end).
- Fixed-commission mismatch surfaces the domain error inline; matching terms
  publish successfully.
- Region fee round-trip: check region + fee → save → reload shows fee;
  uncheck region → fee removed.
- Restricted edit: published offer's pricing inputs absent/read-only;
  update_terms path still works.
- Index actions: publish/pause/republish/archive transition and re-render;
  crafted event with a foreign offer id → flash, no crash, no change.

## Out of scope (later sub-projects / follow-ups)

- Charging dispatch fees at checkout/settlement (sub-project 2 — decided:
  fees WILL be charged; spec to follow).
- Connection request/approval notifications (sub-project 3 — SMS + WhatsApp
  + in-app/push).
- Retiring the Earn-catalog section; offer analytics (import counts, sales);
  post-publish price edits (deliberately locked); pagination past the
  200-offer catalog cap.
