# GhanaPost GPS + Landmark Addressing — Design

**Date:** 2026-07-30
**Status:** Approved (brainstorm with Kojo, 2026-07-30)
**Spec 4 of 4** in the Ghana trust-commerce series. Independent of TC-1..3;
improves delivery success for every order, however it was placed.

## Purpose

Street addresses are unreliable in Ghana; riders navigate by landmarks, and
the national GhanaPost GPS digital address (`GA-183-8164`) is the official
alternative nobody's checkout asks for. Two small fields — a validated
digital-address code and a free-text landmark — make every delivery more
findable. Cheapest effort-to-value item in the series.

## Decisions (agreed during brainstorm)

1. **Both fields optional, landmark nudged.** Nothing blocks checkout —
   forced fields kill mobile conversion and many buyers don't know their
   code. The landmark field carries a strong placeholder ("e.g. behind
   Achimota Melcom, blue gate") and delivery-collecting flows show a
   "helps the rider find you faster" hint.
2. **Format-only validation in v1.** No GhanaPost API verification (a
   commercial API needing keys — a follow-up only if delivery-failure data
   justifies it) and no region-letter cross-checking: over-validation that
   rejects real codes is worse than none.

## Fields

- `digital_address` — GhanaPost GPS code. Normalized (trim, upcase,
  spaces→hyphens: `ga 183 8164` → `GA-183-8164`; separator-less input is
  re-hyphenated deterministically — 2 leading letters, last 4 digits, the
  middle group is what remains: `GA1838164` → `GA-183-8164`), then validated
  against `^[A-Z]{2}-\d{3,4}-\d{4}$` **only when present**; empty always
  passes.
- `landmark` — free text, max 200 chars.

## Components

- **`Emakola.GhanaDigitalAddress`** — tiny pure module (`normalize/1`,
  `valid?/1`), unit-testable like `PlatformFee`. Used by every surface that
  accepts the field.
- **`Emakola.Customers.Address`** — two new attributes + migration,
  accepted in create/update actions.
- **`Order.shipping_address` / `billing_address`** — schemaless `:map`
  attributes; the new keys flow through `CheckoutService` opts with **zero
  migration**.
- **One shared address-fieldset function component** used by all four buyer
  surfaces: storefront checkout (the single shared
  `default_renderers/checkout.ex` — verified the only checkout form; all 20
  themes delegate to it), pay-link express checkout (TC-1), susu delivery
  details (TC-3), and the customer account address book.

  *Ordering independence:* TC-1/TC-3 may land before this spec. Whichever
  lands first builds the plain fieldset; this spec then extracts it into the
  shared component and adds the two fields — or, if TC-4 lands first, TC-1/
  TC-3 consume the component directly. No hard dependency either way.

## Merchant-facing rendering

- Admin order show: the delivery card renders both fields; the digital
  address is copyable (it's what a merchant pastes to a dispatch rider).
- Delivery email: includes both fields where the address already renders.
- `Admin.StoreAddressLive`: same two fields on the store's own address, for
  pickup/dispatch-origin parity.

Surgical rule: the fields appear **only where addresses already render**.
Surfaces without addresses today (e.g. the WhatsApp cart text) stay
untouched.

## Testing

- **Normalization/validation table tests**: valid formats (2-letter +
  3-or-4 + 4 digit groups), messy inputs (`ga 183 8164`, lowercase, mixed
  separators), invalid shapes rejected with a friendly message (never a
  crash), empty/nil always valid.
- **Persistence**: through the `Address` resource and through the checkout
  map path onto the order.
- **Component**: renders on all four buyer surfaces; hint text present in
  delivery-collecting flows.
- **Optionality**: checkout completes with both fields blank.
- **Merchant rendering**: admin order show and delivery email display both
  fields when present, omit cleanly when absent.

## Out of scope

- GhanaPost API lookup / geocoding / map pins.
- Nigeria (NIPOST) addressing — revisit at expansion.
- Rider-app or dispatch-aggregator integration.
- Backfilling existing addresses.
- Adding address blocks to surfaces that don't render them today.

## Success criteria

1. Tests above green; `mix format` / `credo --strict` clean.
2. A buyer can check out with a messy-but-real code and see it stored
   normalized; a nonsense code gets a friendly correction; blank fields
   never block.
3. A merchant viewing a delivery order can copy the digital address and
   read the landmark at a glance.
