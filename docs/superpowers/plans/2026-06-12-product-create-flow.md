# Product Create Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A merchant can create a product with price + images from either "+ New" entry point, publish it in one step, and see it on their storefront — with honest feedback when publishing isn't possible.

**Architecture:** Extract the slide-over's proven image-upload UI/pipeline and price parsing into shared modules under `lib/emakola_web/live/admin/product_live/`; add price→default-variant creation and honest publish flashes to both editors (`ProductLive.Form` and the index slide-over). No schema changes; `Catalog.create_variant` already exists.

**Tech Stack:** Phoenix LiveView (live uploads), Ash (Catalog domain), Tigris via `Emakola.Storage`.

**Spec:** `docs/superpowers/specs/2026-06-12-product-create-flow-design.md`
**Branch:** `feature/product-create-flow`

**Key facts for implementers:**
- Variant price is **integer minor units** (pesewas): `attribute :price, :integer`, must be > 0 (`variant.ex:58,147`). Creation example (from `priv/repo/seeds.exs:380`): `%{product_id: ..., store_id: ..., price: 85_000, sku: "KK-ADW-6YD", stock_quantity: 8, position: 0}` — verify the variant `:create` action's accepted/required fields in `lib/emakola/catalog/resources/variant.ex` before finalizing the attrs map.
- GHS→pesewas parsing exists: `parse_price_input/1` + a pesewas formatter in `index.ex:1212-1226`.
- Upload UI markup: `index.ex` ~864-945 (existing-images grid + drop area + previews + errors); consume pipeline: `index.ex:1344-1365` (`consume_uploaded_entries` → `Emakola.Storage.upload` → `Emakola.Catalog.create_image`); `allow_upload(:product_images, ...)` opts at `index.ex:46`.
- Silent-swallow sites to eliminate: `index.ex:1106-1116` and `form.ex:281-310` (`{:error, _} -> {:ok, product}` inside the `:active` paths).
- Storefront visibility: products must be `status: :active` (`product_list_live.ex:204`); `store_live.ex:181` also filters variants by `& &1.active` — the test in Task 2 must assert the created product actually comes back from `Emakola.Catalog` storefront reads, which catches any missed variant attribute (e.g. an `active` flag defaulting wrong).
- **Browser-faithful tests** (PR #131 lesson): drive events through `element(...)`/`form(...)`/`file_input(...)` selectors, never bare `render_change(view, event, params)` for things a browser must reach through the DOM.

---

### Task 1: Extract shared image-upload component + money helpers (pure refactor)

**Files:**
- Create: `lib/emakola_web/live/admin/product_live/shared.ex` — one module, three responsibilities:
  - `upload_area/1` function component (attrs: `uploads` (the `@uploads` map), `existing_images` (list, default `[]`)) — markup ported verbatim from `index.ex` ~864-945. Emits the same `"delete_image"` / `"cancel_image_upload"` events (parent LiveView keeps the handlers).
  - `save_uploaded_images(socket, product)` — ported verbatim from `index.ex:1344-1365`.
  - `parse_price_input/1` and `format_pesewas/1` — moved from `index.ex:1212-1226` (make public, keep behavior identical).
- Modify: `lib/emakola_web/live/admin/product_live/index.ex` — replace the inline markup/helpers with `Shared.upload_area`, `Shared.save_uploaded_images`, `Shared.parse_price_input`, `Shared.format_pesewas`; delete the now-private duplicates.

- [ ] Step 1: Run `mix test test/emakola_web/live/admin/product_live_test.exs` (or wherever index tests live — find with `ls test/emakola_web/live/admin/`) to record the green baseline.
- [ ] Step 2: Create `shared.ex`, port code verbatim (component markup, consume helper, money helpers).
- [ ] Step 3: Rewire `index.ex` to use it; remove the originals.
- [ ] Step 4: Same test files green again (pure refactor — zero behavior change). `mix format && mix credo --strict`.
- [ ] Step 5: Commit `refactor(web): extract shared product image upload + money helpers`

### Task 2: Form page — price field, default variant, honest publish (TDD)

**Files:**
- Test: `test/emakola_web/live/admin/product_form_test.exs` (create if missing; check for an existing form test file first)
- Modify: `lib/emakola_web/live/admin/product_live/form.ex`

- [ ] Step 1 (RED): Write failing tests (use existing admin test setup conventions — factory store + merchant + auth):
  ```elixir
  test "creating with a price publishes a product visible to the storefront" do
    # fill #product-form (give the form this id in Step 2) via form(...) with
    # title + price "25.00", submit with _action=activate
    # assert product status == :active
    # assert [%{price: 2500}] = product.variants
    # assert storefront :list_by_store_and_status (:active) includes it
    # assert flash =~ "Product published"
  end

  test "activating without a price saves a draft and says so" do
    # submit with title only, _action=activate
    # assert status == :draft and flash =~ "Saved as draft — add a price"
  end
  ```
  Write them as real code against the actual factories — read `test/support/factory.ex` and an existing admin LiveView test for the auth/store pattern first.
- [ ] Step 2 (GREEN): In `form.ex`:
  - Add `id="product-form"` to the main `<form>`; add a Price (GHS) input `name="product[price]"` with help text "e.g. 25.00", shown on `:new` always, and on `:edit` only when the product has no variants (rescues stuck drafts).
  - In `save_product`: parse price via `Shared.parse_price_input/1`. After successful `create_product` (or no-variant `update_product`), when a valid price is present, create the default variant:
    `Emakola.Catalog.create_variant(%{product_id: p.id, store_id: p.store_id, price: pesewas, sku: "SKU-" <> String.slice(Ecto.UUID.generate(), 0, 8), position: 0, ...required-fields-per-resource}, authorize?: false)`
  - Then attempt activation only when `_action == "activate"` AND replace the silent swallow:
    - activated → `put_flash(:info, "Product published — it's live on your store.")`
    - not activated → `put_flash(:warning, "Saved as draft — add a price to publish it.")` (check which flash kinds the admin layout renders — use `:error`-adjacent kind that's actually displayed; verify `flash_group` support for `:warning`, else use `:info` wording differences)
  - Invalid (non-empty but unparseable) price → form error, no save.
- [ ] Step 3: Tests green; `mix format && mix credo --strict`.
- [ ] Step 4: Commit `feat(catalog): price creates default variant + honest publish feedback on product form`

### Task 3: Form page — image upload (TDD)

**Files:**
- Test: same form test file
- Modify: `lib/emakola_web/live/admin/product_live/form.ex`

- [ ] Step 1 (RED): test — `file_input(view, "#product-form", :product_images, [...])` + `render_upload`, submit, assert `Catalog.Image` record exists for the product (use a tiny PNG fixture; check how existing index upload tests do it — if none exist, build the fixture inline with a base64 1×1 PNG). Plus on `:edit`: existing image renders and `delete_image` removes it.
- [ ] Step 2 (GREEN): `allow_upload(:product_images, ...)` in mount (same opts as index); render `Shared.upload_area` inside the main form (live uploads require it inside the form); after successful save call `Shared.save_uploaded_images(socket, product)`; add `delete_image` + `cancel_image_upload` handlers (port from index).
  - NOTE: `Emakola.Storage.upload` hits Tigris — check how index tests handle storage in test env (mock/local adapter?); follow the same pattern so tests don't hit real S3 (CLAUDE.md: never hit real APIs in tests).
- [ ] Step 3: green + format + credo. Commit `feat(catalog): image upload on the product form page`

### Task 4: Slide-over — price on create + honest publish (TDD)

**Files:**
- Test: the existing index test file
- Modify: `lib/emakola_web/live/admin/product_live/index.ex`

- [ ] Step 1 (RED): via `form("#product-slide-over-form", ...)`: create with price + activate → `:active` with default variant + "Product published" flash; create without price + activate → `:draft` + draft flash.
- [ ] Step 2 (GREEN): price input in the slide-over when `@editing_product == nil` (`name="product[price]"`); same default-variant + flash logic as Task 2 — extract the common save sequence into `Shared.create_product_with_price(attrs, pesewas_or_nil, action)` used by BOTH editors (refactor form.ex to call it too); both silent swallows gone.
- [ ] Step 3: green + format + credo. Commit `feat(catalog): price on create and honest publish feedback in product slide-over`

### Task 5: Gate, ship, verify in production

- [ ] Step 1: Scoped suites green (form/index/onboarding/landing); fresh-compile CI-equivalent: `mix clean --only app && mix test --warnings-as-errors 2>&1 | tail -3` (compare failure count to the known local-env baseline; CI is the gate).
- [ ] Step 2: Push, `gh pr create --base main`, wait checks, merge (update branch if BEHIND), wait main CI (rerun once on ChromicPDF flake), deploy: `git checkout --detach origin/main && fly deploy --app emakola`.
- [ ] Step 3: Production E2E — **in an isolated browser context only** (`page.context().browser().newContext()` — NEVER reuse the default context: it is the user's real Chrome session): log in as the claude-test account, Products → both "+ New" paths → create a product with price + image → publish → assert it renders at the storefront `/s/<their-store>` product list. Report results with the product left in place for the user to see.
