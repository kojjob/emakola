# Snap-to-Shop — Design Spec

**Date:** 2026-08-05
**Status:** Approved (brainstormed with Kojo, phone session)
**Depends on:** AI foundation (#246/#389, live in prod), S3 upload pipeline, PDP parity (#350), Content.RateLimiter

## Problem & value

Makola's target merchants — IG/WhatsApp social sellers, many with limited literacy —
find product listing the highest-friction step on the platform: it demands written
titles, descriptions, and category choices. Meanwhile the deepest trust problem in
West African online buying is "what I ordered vs what I got": listings whose photos
are not the goods actually sold.

Snap-to-Shop attacks both at once. A merchant photographs their goods; Claude's
vision builds the entire listing from that exact photo; the photo *is* the listing
image by construction. Products that pass the honesty gates earn a storefront
"Real photo" badge — extending the trust-commerce arc (pay links, buyer
protection) to *seeing is believing*.

Cost per listing ≈ 2–3 US cents (Sonnet 5 vision). Every listing created is
inventory that can earn transaction fees.

## User journey (v1)

1. **Entry:** a prominent "📸 Add by photo" button on `/admin/products` and a
   dashboard quick-action. Renders only when AI is configured (same ship-dark
   pattern as the SEO quick-wins page).
2. **Capture:** new LiveView `Admin.ProductLive.Snap` at `/admin/products/snap`.
   Camera-first via a full-size `opacity-0` overlay file input with
   `capture="environment"` (the iOS-Safari-safe pattern from PR #141/#145 — NO
   `sr-only` inputs). Gallery selection is allowed but recorded as
   `source: :gallery` (affects badge eligibility only, invisible otherwise).
3. **Upload:** existing `allow_upload` pipeline with `auto_upload: true` (avoids
   the progress-gate deadlock), stored via the standard S3/Tigris path. The
   public image URL is what the AI call consumes (proven pattern — the prod
   alt-text smoke call).
4. **Reading state:** vision call runs in `start_async` (~5–8s). Visual-first
   waiting state; copy within the ≤8-word ceiling ("Reading your photo…").
5. **Review card:** photo on top; AI-filled title, description, category, tags
   below; one big empty **GHS price** field the merchant MUST fill (money is
   never guessed); buttons **Save Draft** / **Publish** (mirroring the existing
   form's draft/activate semantics). Publishing creates a normal product through
   the existing create action with the photo attached as primary image.
6. **Failure states:**
   - AI cannot identify the product (`identified: false`) → friendly retry
     state, "Try a clearer photo" + icon. No product created; usage still metered.
   - Photo flagged as stock/watermark/screenshot → amber warning on the review
     card ("Buyers trust real photos" + visual cue). Merchant may still publish;
     the product is permanently badge-ineligible.
   - Provider error/timeout → retry state; no partial product.

## AI contract

New prompt `:snap_to_shop` in `Emakola.AI.Prompts`:

- **Input:** image content block (public URL) + store context: store name and the
  merchant's existing category names (list of strings).
- **Model:** the longform model (`claude-sonnet-5`) with the mandatory
  `thinking: :disabled` flag per the #389 contract. Quality matters for
  merchant-facing copy; revisit tier after usage data.
- **Output:** schema-enforced JSON via `json_schema` (closed schema, no parsing
  gambles):

```json
{
  "identified": true,
  "title": "string (≤ 60 chars)",
  "description": "string (2-4 sentences)",
  "category": "one of the provided category names, or null",
  "tags": ["string", "..."],
  "alt_text": "string (≤ 125 chars)",
  "photo_flags": {
    "stock_photo": false,
    "watermark": false,
    "screenshot": false
  }
}
```

- **System rules:** the no-invented-provenance rule verbatim from
  `:product_description` — describe only what is visible; never invent material,
  ingredient, origin, size, certification, or performance claims. Alt-text rules
  match `:image_alt_text`.
- **Metering:** every call records an `Emakola.AI.Usage` row (existing
  foundation behavior). The model MUST have a positive `:ai_model_pricing` entry
  (pricing tripwire enforces this in test).

## Image-truth guarantee & the "Real photo" badge

The listing image and description cannot disagree: the description is generated
from the image, and the snapped photo is auto-attached as the product's primary
image during creation — not optional, no substitution during the flow.

**Badge award** (`snap_verified: true` at creation) requires ALL of:
1. Product created through the Snap flow,
2. Photo source was the live camera (`:camera`, not `:gallery`),
3. All `photo_flags` clean.

**Badge revocation** — the badge is a promise; it must be impossible for it to
lie. `snap_verified` flips to `false` automatically when the product's primary
image is replaced, removed, or reordered so a different image leads. Enforced in
the image-management/product-update actions (domain layer), NOT in the UI —
there is no route around it. Text edits do NOT revoke (the photo is the promise,
not the words). Revocation is one-way in v1: no re-earn without a new Snap flow.

**Storefront:** one shared PDP badge component (visual-first: 📷 + "Real photo",
≤8-word tooltip), rendered via the shared PDP surface established by the PDP
parity work (#350) so all themes get it from a single component. v1 scope:
PDP only — NOT on product cards/grids.

## Data model

No new resources.

- `Product.snap_verified` — boolean, default `false`, non-nullable.
- Capture source on the upload flow (transient or image metadata — implementer's
  choice, but revocation logic must not depend on transient state).
- All creation/updates flow through existing tenant-scoped actions.

## Guardrails

- **Rate limit:** existing `Content.RateLimiter`, per-store daily cap shared with
  the other AI content features (no separate budget pool).
- **Ship-dark:** no AI key → entry button absent; direct route access shows the
  same "not switched on" state as the SEO page.
- **Money:** price is merchant-entered only. No AI price suggestions in v1.
- **Multitenancy:** store context comes from the authenticated merchant session;
  category list passed to the prompt is the tenant's own.

## Testing

TDD throughout; mock the provider (`Emakola.AI.ProviderMock`) — never hit the API.

1. **Prompt contract:** `:snap_to_shop` builds the expected Request (model,
   thinking flag, schema present, provenance rule present in system text);
   pricing tripwire covers the model.
2. **LiveView flow:** upload → async → review card renders AI values → price
   required → Save Draft creates draft product with photo as primary image and
   correct `snap_verified`.
3. **Badge award matrix:** camera+clean → true; gallery → false; any flag →
   false (and warning rendered).
4. **Revocation:** image replace/remove/reorder → `snap_verified: false`; title
   or description edit → unchanged. Domain-level tests (action layer), not UI.
5. **Failure states:** `identified: false` → retry state, no product;
   provider error → retry state.
6. **Storefront:** badge renders on PDP for a verified product and is absent
   after revocation, across a sample of themes.
7. **Structural guard:** extend the existing no-invented-provenance test surface
   to cover the badge copy (badge promises only "real photo", nothing more).

## Explicitly out of scope (v1)

- Multi-product stall scans (several products from one photo)
- AI price suggestions (revisit when platform comparable data is thick)
- Non-English output (Twi/Hausa/Yoruba — belongs to the localization feature)
- Badge on product cards/grids or category pages
- Flutter app surface (web-mobile first; API can follow)
- Re-earning a revoked badge without a fresh Snap flow
- Image enhancement/background cleanup (separate feature; different providers)
