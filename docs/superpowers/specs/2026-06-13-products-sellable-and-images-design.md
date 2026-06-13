# Products Sellable by Default + Public Product Images

**Date:** 2026-06-13
**Status:** Approved direction (user chose "default to sellable without inventory
tracking"); two production bugs found by the customer-journey smoke test.

## Bug 1 — products created via the new flow are unbuyable (revenue blocker)

**Root cause (verified in prod):** the create flow's default variant is made with
`track_inventory: true` (the attribute default) and `stock_quantity: 0`. The storefront
add-to-cart gates check stock **unconditionally** and refuse anything at 0:

- `product_detail_live.ex:138` — `is_nil(variant) || variant.stock_quantity <= 0`
- `store_live.ex:84` — `if variant && variant.stock_quantity > 0`
- `category_live.ex:85` — `if variant && variant.stock_quantity > 0`

So a merchant can create + publish a product, but no customer can add it to cart — it
silently flashes "out of stock". `checkout_service` already does the right thing
(`variant.track_inventory and variant.stock_quantity < qty`), so the gates are
inconsistent with checkout. The same unconditional gate also blocks **dropshipped**
variants (forced `track_inventory: false`, `stock_quantity: 0`) — latently broken today.

**Fix (two coordinated parts):**

1. **Sellable-by-default.** The create flow (`Shared.create_product_with_price` →
   `maybe_create_default_variant`, used by both the form page and the slide-over) creates
   the default variant with `track_inventory: false`. For Emakola's low-literacy
   merchants this means "just sell" — inventory tracking becomes an opt-in toggle later
   (out of scope here). The `UntrackDropshippedInventory` change leaves no-supplier
   variants' `track_inventory` as the caller set it (verified), so `false` sticks.

2. **One canonical stock predicate.** Add `Emakola.Catalog.Variant.in_stock?/2`:
   ```elixir
   def in_stock?(variant, qty \\ 1),
     do: not variant.track_inventory or variant.stock_quantity >= qty
   ```
   Use it in the three storefront gates (respecting the page's chosen quantity on the
   product page) and refactor `checkout_service.validate_stock/2` to use it too
   (`not Variant.in_stock?(variant, qty)` is the insufficient condition — logically
   identical to today's inline check). This kills the duplicated, drifted stock logic
   that caused the bug and makes dropshipped + untracked products buyable.

**Out of scope:** a stock-quantity field / track-inventory toggle on the create form
(future enhancement); inventory management UI.

## Bug 2 — product images return HTTP 403 (broken images for customers)

**Root cause (verified):** uploads succeed (`s3.ex` sends `acl: "public-read"`), but a
public GET of the object returns 403 from Tigris. Tigris buckets are private by default
and do not honor per-object `public-read` ACLs unless the bucket itself permits public
reads. This is **not** an AWS-vs-Tigris issue — an S3 bucket is private by default too.

**Fix:** make the existing `emakola-uploads` Tigris bucket serve public reads (a one-time
bucket-level configuration — public bucket setting or a public-GET bucket policy applied
via the S3 API against the Tigris endpoint), then re-verify an uploaded object returns
200 and renders on the storefront. No application URL change if `public_url/1` already
points at the right host (verify). Keep Tigris. Exact mechanism pinned during
implementation; if it requires a credential the agent lacks, hand the user the exact
command.

## Testing

- Unit: `Variant.in_stock?/2` — tracked (in/at/over qty), untracked (always true incl.
  stock 0).
- Create flow: creating a product with a price yields a variant with
  `track_inventory == false`.
- Storefront (browser-faithful LiveView test): `add_to_cart` succeeds for an untracked
  zero-stock variant; still refuses a tracked zero-stock variant.
- `checkout_service` stock tests stay green after the refactor.
- Production: create a product → add to cart → reach "Proceed to Checkout"; uploaded
  image returns 200 and renders.
