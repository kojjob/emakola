# Bulk Product Upload — Phase 1: Photo-First Flow

**Date:** 2026-06-13
**Status:** Approved design (brainstormed with mockups), pending implementation plan
**Mockup:** `.superpowers/brainstorm/31034-1781366434/content/photo-first-flow.html`

## Context & decomposition

"Merchants should be able to bulk-add products with all details and images." The user
chose **both** a phone-native photo-first flow and an enhanced CSV importer. These are two
independent features, built as separate spec → plan → ship cycles:

- **Phase 1 (this spec): Photo-first bulk upload** — the phone-native path for low-literacy
  market merchants whose products live as photos on their phone.
- **Phase 2 (separate, later): Enhanced CSV** — add image support and fix the existing
  `Emakola.Catalog.CsvImporter` gaps (it stores price as raw pesewas so "150" → GH₵1.50;
  leaves imported products as invisible drafts; silently swallows variant failures). **Out
  of scope here.**

## Goal

A merchant selects many product photos from her phone at once, types a name + price into a
card per photo, and publishes them all as live, sellable products in one action.

## User flow

Single-scroll dedicated page (the mockup's "3 steps" are conceptual; the real screen is one
page so she never loses her place):

1. **Select** — a drop/select zone with one multi-file input; she picks all product photos
   from the gallery at once.
2. **Fill** — each photo becomes a card below, inline, with a large **Name** input and a
   large **Price (GHS)** input. Photos stream to the server as selected (progress shown).
3. **Publish** — a sticky bottom bar "Publish N products" creates every complete card.

**Minimal fields by design:** photo + name + price only. Category, description, variants,
and SEO stay in the single-product editor and the Phase 2 CSV path — this flow optimizes
for speed and low literacy.

## Where it lives

- New route `live "/admin/products/bulk", Admin.ProductLive.BulkPhoto` in the authenticated
  admin scope (same `live_session` as the other product routes).
- New LiveView `EmakolaWeb.Admin.ProductLive.BulkPhoto` (its own module/file).
- Entry point: an "Add many products" button beside "+ New Product" on the products index
  header (`product_live/index.ex`), linking to the new route.

## Architecture & data flow

- **Upload:** `allow_upload(:photos, accept: ~w(.jpg .jpeg .png .webp), max_entries: 30,
  max_file_size: 10_000_000)`, rendered with `live_file_input ... multiple`. Each selected
  photo is one LiveView upload entry = one card.
- **Card state:** an assign `cards` keyed by upload entry `ref` → `%{name, price}`. `validate`
  (phx-change) keeps names/prices in sync as she types; entries removed via
  `cancel_upload`.
- **Per card UI:** `live_img_preview` of the photo, Name input, Price input, remove (×),
  and per-card progress/error.
- **Publish (`publish_all` event):** for each card with a non-empty name **and** a valid
  price (parsed with `Shared.parse_price_input/1`):
  1. `Shared.create_product_with_price(%{title: name, store_id: store_id}, pesewas,
     :activate)` — reuses the single-add path: product → default variant
     `track_inventory: false` → activate → **sellable by default**. Returns the product.
  2. Build a `ref → product_id` map for the cards that produced a product.
  3. `consume_uploaded_entries(socket, :photos, fn %{path: tmp}, entry -> ... end)` — for
     each consumed entry, upload to Tigris and `Catalog.create_image` for the mapped
     product. (This is per-entry-to-different-product, so it does **not** reuse
     `Shared.save_uploaded_images/2`, which attaches all entries to one product — the plan
     adds a small `Shared.upload_one_image/3` or inline equivalent.)
- **Result:** flash `:info` "N products published", `push_navigate` to `/admin/products`.

## Error handling

- A card missing a name or a valid price is **skipped and visibly flagged** ("add a price"),
  never silently. Publish proceeds with the valid cards.
- A storage/`create_image` failure for one photo flags that card (reuse the rescue pattern
  from `Shared.save_uploaded_images`); the product is still created, the batch continues.
- Zero valid cards → inline message, no-op (no redirect).
- Standard upload errors (too large, wrong type, > 30 files) shown per the existing
  `upload_errors` pattern.

## Testing (TDD, browser-faithful)

- Multi-photo upload via `file_input(view, "#bulk-photo-form", :photos, [png1, png2])` +
  `render_upload`, with a Mox-stubbed `Emakola.StorageMock`.
- Publishing 2 complete cards creates 2 `:active` products, each with one
  `track_inventory: false` variant at the right pesewa price and one attached
  `Catalog.Image`; both then returned by the storefront `list_by_store_and_status(:active)`
  read.
- A card with a name but no price is skipped with the warning; its product is not created.
- A storage error on one photo still creates that product (image absent), batch completes,
  failure surfaced.
- Gate: `mix test` (scoped), `mix format`, `mix credo --strict`, clean-compile
  `--warnings-as-errors`.

## Out of scope

- The CSV importer (Phase 2).
- Category, description, multiple variants, SEO in this flow (single-product editor / CSV).
- Inventory-tracking toggle (products default untracked, consistent with single-add).
