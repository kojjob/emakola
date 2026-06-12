# Product Create Flow Completion — Price, Images, Honest Publishing

**Date:** 2026-06-12
**Status:** Approved direction (user: "make sure that process is working perfectly with
all the required attributes like price, images etc"), spec pending review.

## Problem (verified in production)

A merchant who creates a product through either "+ New" entry point gets an invisible,
unpublishable draft with no explanation:

1. `/admin/products/new` (`ProductLive.Form`) collects title/description/category/SEO —
   **no price, no images**.
2. `Catalog.create_product` creates **no default variant**; the `:activate` action
   requires `HasVariants`, so activation always fails for new products.
3. **Both** editors (Form page and products-index slide-over) swallow that failure:
   `{:error, _} -> {:ok, product}` — the UI reports success, the product stays `draft`.
4. The storefront lists only `status: :active` products → merchant sees an empty store.
5. The slide-over has working image upload + per-variant price editing, but only for
   already-existing products/variants; the Form page has neither.

Production evidence: user's "Bamboo Plates" (draft, 0 variants) and "Bamboo Table"
(draft, 1 variant added later via slide-over) — both invisible at their storefront,
while seeded demo products (active, with variants) display fine.

## Goal

From either entry point, a merchant can create a product with a price and images,
publish it in one step, and see it on their storefront — or get told exactly why not.

## Design

### 1. Price → default variant at creation

- Both create paths gain a required-for-publish **Price** field (decimal GHS in the UI,
  converted to integer minor units — pesewas — per the money rule; reuse/extract the
  slide-over's existing price parsing).
- On create with a price: `create_product` → `Catalog.create_variant` (the product's
  default variant carrying the price; satisfy the variant `:create` action's required
  fields the same way `priv/repo/seeds.exs` does — the implementer mirrors that usage) →
  `activate_product` when "Save & Activate" was chosen.
- Editing existing products keeps the current per-variant price editing untouched.

### 2. Image upload on the Form page (and shared with the slide-over)

- Extract the slide-over's upload UI (drag & drop area, previews, progress, cancel,
  existing-image grid with delete) into one shared function component, e.g.
  `EmakolaWeb.Admin.ProductLive.ImageUpload`, and its consume pipeline
  (`consume_uploaded_entries` → `Emakola.Storage.upload` → `Catalog.create_image`)
  into a shared helper.
- `ProductLive.Form` mounts `allow_upload(:product_images, ...)` with the same limits
  as the slide-over and renders the shared component; uploads are consumed right after
  the product is saved (`:new` and `:edit`).
- The slide-over is refactored to use the same component/helper — one implementation,
  two call sites.

### 3. Honest publish feedback (both editors)

- Replace the silent `{:error, _} -> {:ok, product}` swallow:
  - Activation succeeded → flash `:info` "Product published — it's live on your store."
  - Activation failed → product is still saved, but flash `:warning`
    "Saved as draft — add a price to publish it." (plain words, low-literacy friendly)
  - With #1 in place this path should be rare; it must never be silent.

### 4. Entry points

- Header "+ New Product" link → Form page (now complete).
- Products-index "New Product" button → slide-over (gains the same price-on-create and
  feedback behavior).
- Editor consolidation (two duplicate editors) is OUT of scope — follow-up.

## Testing (TDD, browser-faithful)

- Form page: create with title+price (+uploaded image via `file_input`/`render_upload`)
  → assert product `:active`, default variant exists with the right integer price,
  image record attached; the storefront `list_by_store_and_status(:active)` query
  returns it.
- Create without price, "Save & Activate" → product saved as `:draft` AND the
  draft-warning flash is rendered (no silent success).
- Slide-over: same two scenarios through `element("#product-slide-over-form")`.
- All change/submit targeting via `element(...)`/`form(...)` selectors (DOM-faithful —
  the lesson from PR #131).

## Out of Scope

- Consolidating the two editors into one (follow-up).
- Inventory/stock fields, digital files (existing flows untouched).
- Activating the user's existing bamboo drafts (data, not code — user does it in the UI,
  or on request).
