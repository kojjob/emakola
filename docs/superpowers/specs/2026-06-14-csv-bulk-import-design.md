# Bulk Product Upload — Phase 2: Enhanced CSV Importer

**Date:** 2026-06-14
**Status:** Approved design (brainstormed), pending implementation plan
**Phase 1 (photo-first):** shipped (PRs #137, #138).

## Goal

Make the existing CSV bulk import production-ready for literate power-user / wholesaler
merchants: support images (matched by filename), and fix the importer's correctness gaps —
price units, draft visibility, inventory policy, and silent failures.

## Current gaps (verified in `Emakola.Catalog.CsvImporter`)

1. No image support.
2. Price stored as raw pesewas — `"150"` becomes GH₵1.50 instead of GH₵150.
3. Imported products are never activated → invisible drafts on the storefront.
4. Variant-creation failures are swallowed by a bare `rescue _ -> :ok`.
5. `track_inventory` is never set.
6. Parsing is fragile: everything after `stock_quantity` is comma-joined into `tags`, so a
   new column can't simply be appended.

## CSV format & image mechanism (filename-matched upload)

- **New template header (8 fixed columns):**
  `title,description,category,sku,price,stock_quantity,tags,images`
- **Multi-value cells use semicolons**, not commas, so the CSV stays unambiguous with a
  proper parser: `tags` = `fresh;local`, `images` = `okra-1.jpg;okra-2.jpg`. (This replaces
  the old comma-joined-tags behavior — a deliberate parsing upgrade; the template documents it.)
- **`parse/2` is upgraded to a robust CSV parse** with a fixed 8-column contract (handles
  quoted fields; the plan picks NimbleCSV if available, else a hardened split). It stays a
  pure function returning `{rows, errors}`; each row carries `images: [filename, ...]`.
- **The Bulk Upload modal gains a second drop zone** for image files (`allow_upload(:bulk_images, ...)`)
  beside the CSV one. The merchant uploads the CSV and multi-selects all referenced photos.
- **Matching is by filename, case-insensitive.** The first listed filename is the product's
  primary image (position 0). A filename named in a row but not uploaded → a per-row warning
  ("image okra.jpg not found in your uploads"); the product still imports without it.
  Uploaded images that no row references → a single summary note ("N uploaded images weren't used").

## Gap fixes

- **Price → GHS.** Read `price` with the app-wide `parse_price_input` (`"150"` → 15,000
  pesewas). Blank/invalid price → no variant created for that row → it imports as a draft
  with a warning ("add a price to publish"). (Bug-fix regression test required.)
- **Activate.** Each row that gets a priced variant is activated → live on the storefront,
  matching the single-add and photo-first flows.
- **Inventory policy (per row).** `stock_quantity` a positive integer → `track_inventory: true`
  with that count. Blank or `0` → `track_inventory: false` (sellable, untracked — consistent
  with the rest of the app).
- **No silent failures.** The bare `rescue` is removed; every row's outcome is collected and
  shown in the summary.

## Architecture & data flow

- **`Emakola.Catalog.CsvImporter`** (domain):
  - `parse/2` — pure; upgraded parser + the `images` column.
  - `import_rows/3` — new signature `import_rows(rows, store_id, image_urls)` where
    `image_urls` is `%{"filename_downcased" => %{url: ..., content_type: ...}}` (already
    uploaded to storage by the web layer — keeps the importer free of upload internals and
    unit-testable). Per row: create product → parse price → create priced variant with the
    track/stock policy → activate → for each matched filename `Catalog.create_image(url, ...)`.
    Returns `{imported_count, skipped_count, warnings}` (warnings are user-readable strings).
  - Create→variant→activate lives in the domain layer (no dependency on the web
    `Shared.create_product_with_price`). Noted future option: unify both into a single
    `Catalog` function; out of scope here.
- **`EmakolaWeb.Admin.ProductLive.BulkUploadModal`** (web): second `allow_upload(:bulk_images)`
  drop zone; updated template-download header; preview table gains an "Images" column
  (matched ✓ / missing ⚠).
- **`EmakolaWeb.Admin.ProductLive.Index`** (web): on import —
  1. parse CSV → rows; compute the set of referenced filenames.
  2. consume only the uploaded image entries whose filename is referenced → upload each to
     Tigris with `Emakola.Storage.upload/3` (just the upload — `create_image` happens later in
     the importer, once the product exists) → build `image_urls`. (Unreferenced uploads are
     skipped — no orphan objects.)
  3. `CsvImporter.import_rows(rows, store_id, image_urls)` → flash the summary; note unused uploads.

## Error handling

Per-row warnings (missing/invalid price, unmatched image filename, create/variant failure)
are collected and rendered in the import summary — never silent. A referenced-but-unmatched
filename warns and the row still imports. Storage failures for one image flag that image, not
the batch. Summary form: "12 products imported, 3 skipped — Row 4: add a price; Row 7: image
yam.jpg not found".

## Testing (TDD)

- `parse/2`: the `images` column splits on `;`; tags split on `;`; quoted fields with commas
  survive; 8-column contract enforced (too-few-columns row → error).
- `import_rows/3` (Mox-stubbed storage where the web consumes uploads; the importer takes the
  url map directly so it needs no storage stub): full row → `:active` product, priced variant,
  correct `track_inventory`/stock, attached image; blank price → draft + warning + no variant;
  `stock_quantity: 10` → `track_inventory: true`, stock 10; `price "150"` → 15,000 pesewas
  (regression for the unit bug); a row naming an unmatched filename → product imported, warning,
  no image; the imported active products are returned by the storefront active-read.
- LiveView: the modal renders the second drop zone and an updated template header; importing a
  CSV + images produces the products and the summary flash.

## Out of scope

- Image-URL-download and ZIP mechanisms (rejected in favor of filename-matched upload).
- The photo-first flow (Phase 1, shipped).
- Unifying the domain importer with the web `create_product_with_price` (future refactor).
