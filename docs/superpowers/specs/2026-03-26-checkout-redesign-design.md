# Checkout Redesign -- Premium Accordion Flow with Coupons

**Date:** 2026-03-26
**Status:** Approved
**Branch:** `feature/checkout-redesign`

## Overview

Redesign the checkout experience (cart, checkout, payment waiting, and order confirmation pages) to be premium, feature-rich, and responsive. Add a coupon/discount system with full merchant admin CRUD.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Checkout flow | Accordion steps | Guided feel, completed steps collapse to summary, familiar Apple/Stripe pattern |
| Step order | Contact -> Payment -> Review | **Breaking change from current Payment -> Details -> Confirm.** Contact first because delivery region affects fees shown alongside payment options |
| MoMo waiting UX | Rich status flow | Step-by-step progress tracker, countdown timer, USSD fallback -- builds trust |
| Confirmation page | Celebration + timeline | "What happens next" delivery timeline, WhatsApp CTA, product thumbnails |
| Coupons | Full stack (resource + admin UI) | Percentage, fixed amount, free shipping. Merchant-managed via admin dashboard |
| Discount rounding | Truncate (round down) | Integer division truncates in merchant's favor. Documented, not a bug. |

## 1. Data Layer: Product Images in Cart

**Current:** Cart items in ETS store `product_title`, `variant_info`, `unit_price`, `quantity`, `sku`, `variant_id` -- no image.

**Change:** Add `image_url` field to cart item map.

- In `ProductDetailLive`, when adding to cart, look up product's primary image (position 0)
- Store `thumbnail_url || url` as `image_url` in the cart item
- No migration -- ETS map only
- Fallback: styled placeholder when `image_url` is nil or missing
- **Note:** Existing in-flight ETS carts (from before deploy) will have items without `image_url`. The fallback placeholder handles this gracefully -- it's not just for products without images.

**Files:** `lib/emakola/cart/cart_store.ex`, `lib/emakola_web/live/storefront/product_detail_live.ex`

## 2. Cart Page (`CartLive`) Enhancements

- Replace grey placeholder boxes with `item.image_url` -- `<img>` tag with `object-cover`, rounded corners
- Fallback to shopping bag SVG icon when no image (or nil/missing key)
- Add collapsible mobile order summary (currently `hidden lg:block`)
  - Tap "Order Summary (N items)" to expand/collapse on mobile
  - Always visible on desktop as sticky sidebar

**Files:** `lib/emakola_web/live/storefront/cart_live.ex`

## 3. Checkout Page (`CheckoutLive`) -- Accordion Redesign

**BREAKING CHANGE:** Step order is reversed from the current implementation.
- Current: Step 1 = Payment, Step 2 = Details, Step 3 = Confirm
- New: Step 1 = Contact & Delivery, Step 2 = Payment, Step 3 = Review & Pay
- All `go_to_step` event handlers, `submit_details` (currently hardcoded to advance to step 3), and step indicator labels must be updated accordingly.

### Layout

- Single column main content (max-w-2xl) with sticky sidebar on desktop (w-80)
- Sidebar shows order items with thumbnails, quantities, prices, coupon discount, totals
- Mobile: collapsible order summary at top

### Progress Bar

3-segment bar at top. Segments fill green (#059669) as steps complete.

### Step 1: Contact & Delivery (first step -- needed before payment)

- Phone input with +233 prefix
- Full name input
- Delivery address input
- Region dropdown (Greater Accra, Ashanti, Central, Western, Eastern, Northern, Volta, Other)
- Order notes (optional)
- Inline validation: red border + helper text on blur for empty required fields
- Dynamic delivery fee on region change
- "Continue" validates and collapses section

### Step 2: Payment Method

- 2x2 grid of payment cards
  - MTN Mobile Money: yellow accent (#FFC107)
  - Telecel Cash: red accent (#E60000)
  - Card Payment: blue accent (#3B82F6)
  - Cash on Delivery: grey accent (#64748B)
- Selected card: accent border + checkmark icon
- "Continue" collapses to show selected method

### Step 3: Review & Pay

- Coupon code input with "Apply" button (see section 4)
- Order items with thumbnails
- Delivery summary (name, address, phone)
- Payment method summary
- Subtotal, discount (if coupon applied), delivery fee, total
- "Place Order" / "Pay GH₵ XXX.XX" button
- Each collapsed section shows summary + "Edit" link

### Completed Section Collapse

When a step is completed and user advances:
- Section collapses to single-line summary (e.g., "Ama Mensah, Osu Badu St, Greater Accra")
- Green checkmark on step number
- "Edit" link to reopen

### State Management

- Same assigns as current (`step`, `payment_method`, `phone`, `fullname`, `address`, `region`, `notes`, `delivery_fee`)
- Add: `coupon_code`, `coupon`, `discount_amount`, `coupon_error`

**Files:** `lib/emakola_web/live/storefront/checkout_live.ex`

## 4. Coupon/Discount System

### Ash Resource: `Emakola.Orders.Coupon`

```
Domain: Emakola.Orders
Table: coupons

Attributes:
  - id: uuid (PK)
  - store_id: uuid (required, multi-tenant)
  - code: string (required, uppercase, unique per store)
  - description: string (optional, merchant-facing)
  - discount_type: atom [:percentage, :fixed_amount, :free_shipping]
  - discount_value: integer (pesewas for fixed, basis points for percentage -- 1000 = 10%)
  - max_discount_amount: integer (pesewas, optional -- caps percentage discounts to prevent 100% off accidents)
  - minimum_order_amount: integer (pesewas, optional -- minimum subtotal to qualify)
  - max_uses: integer (optional -- nil means unlimited)
  - uses_count: integer (default 0)
  - starts_at: utc_datetime (optional)
  - expires_at: utc_datetime (optional)
  - active: boolean (default true)
  - timestamps

Actions:
  - :create -- merchant creates coupon (validate percentage <= 10000)
  - :update -- merchant edits coupon
  - :deactivate -- sets active to false
  - :increment_usage -- atomic increment of uses_count
  - :list_by_store -- paginated list for admin
  - :find_by_code -- read action to find by store_id + uppercase(code)

Note: Coupon validation logic (active, not expired, usage limits, minimum order)
lives in CheckoutService, NOT as an Ash action. The resource only provides
data access. This keeps validation close to the business logic and allows
passing runtime params like subtotal.

Identities:
  - unique [:store_id, :code] (case-insensitive)
```

### Admin Route

**Use `/admin/coupons`**, separate from the existing `/admin/discounts` route. Coupons are customer-facing codes; the existing discounts page (if any) handles merchant-side pricing. They are distinct concepts.

### Validation Logic (in CheckoutService)

```
validate_coupon(store_id, code, subtotal):
  1. Find coupon by store_id + uppercase(code) via :find_by_code
  2. Check active == true
  3. Check not expired (expires_at nil or > now)
  4. Check started (starts_at nil or <= now)
  5. Check uses_count < max_uses (or max_uses is nil)
  6. Check subtotal >= minimum_order_amount (or minimum is nil)
  7. Return {:ok, coupon} or {:error, reason}

calculate_discount(coupon, subtotal, delivery_fee):
  - :percentage ->
      raw = div(subtotal * coupon.discount_value, 10_000)
      if coupon.max_discount_amount, do: min(raw, coupon.max_discount_amount), else: raw
  - :fixed_amount -> min(coupon.discount_value, subtotal)
  - :free_shipping -> delivery_fee

Note: Integer division truncates (rounds down), always in the merchant's favor.
Example: 15% of GHS 1.50 (150 pesewas) = 22 pesewas (not 22.5).
```

### Checkout Integration

- Coupon input in Step 3 (Review): text field + "Apply" button
- On apply: `validate_coupon` -> show discount line or error message
- "Remove" link to clear applied coupon
- Order summary shows: Subtotal, Discount (-GH₵ X.XX), Delivery, Total
- On `place_order`:
  1. **Re-validate coupon inside the DB transaction** (time passes between "Apply" click and "Place Order" click -- coupon could expire or hit max uses)
  2. If still valid: increment usage atomically via `:increment_usage` action
  3. If no longer valid: roll back transaction, show error, clear coupon from UI
  4. Race condition (two orders use last remaining use): `increment_usage` uses atomic update with `uses_count < max_uses` guard. If the update affects 0 rows, treat as invalid.
- Store `coupon_id` and `discount_amount` on Order resource

### Migration

**Single migration** (ships together, no reason to split):
1. Create `coupons` table with all attributes
2. Add to `orders` table: `coupon_id` (uuid, nullable, references coupons), `delivery_fee` (integer, default 0), `discount_amount` (integer, default 0)

**Why `delivery_fee` and `discount_amount` on Order?** Currently only `subtotal` and `total` are persisted. Without these fields, the order total is non-auditable (`total = subtotal - discount + delivery_fee` but only `total` is stored). Adding them makes the confirmation page and admin order detail accurate.

**Files:**
- `lib/emakola/orders/resources/coupon.ex` (new)
- `lib/emakola/orders/resources/order.ex` (add coupon relationship, delivery_fee, discount_amount)
- `lib/emakola/orders/orders.ex` (register Coupon resource -- note: actual path, not `lib/emakola/orders.ex`)
- `lib/emakola/orders/checkout_service.ex` (coupon validation + discount calculation)
- `priv/repo/migrations/*_add_coupons_and_order_fields.exs` (single migration)

## 5. Merchant Admin Coupon UI

### Route: `/admin/coupons`

LiveView at `lib/emakola_web/live/admin/coupon_live.ex`

### List View
- Table: Code, Type, Value, Uses, Status (active/expired/maxed), Actions
- "Create Coupon" button
- Toggle active/inactive inline
- Search/filter by code

### Create/Edit Modal or Page
- Code (auto-uppercase, validated unique per store)
- Description (optional)
- Discount type dropdown (Percentage, Fixed Amount, Free Shipping)
- Discount value (conditionally shown -- not for free_shipping)
  - Percentage: input as whole number (10 = 10%), stored as 1000 basis points. Validated <= 100%.
  - Fixed: input as cedis, stored as pesewas
- Max discount amount (optional, for percentage coupons -- caps the discount)
- Minimum order amount (optional, input as cedis)
- Max uses (optional)
- Start date (optional date picker)
- Expiry date (optional date picker)
- Active toggle

**Files:** `lib/emakola_web/live/admin/coupon_live.ex` (new), `lib/emakola_web/router.ex`

## 6. Mobile Money Rich Waiting State

Replaces the amber box in `CheckoutLive`. Shown when `payment_status == :awaiting_payment`.

### UI Elements
- Phone icon with MoMo brand-color halo (yellow for MTN, red for Telecel)
- "Approve on your phone" heading
- 3-step progress tracker:
  1. Order created -- green check, shows order number
  2. Payment request sent -- green check, shows masked phone
  3. Awaiting approval -- pulsing amber dot, "Dial *170# if you don't see the prompt"
- Countdown timer: starts at 3:00, counts down each second
- "Didn't receive the prompt? Get help" link
- On timeout: show "Payment timed out" with Retry button
- On failure: show "Payment failed" with Retry button

### Timer Implementation
- Add `timer_seconds` assign (starts at 180)
- Add `:tick_timer` handle_info that decrements every second via `Process.send_after(self(), :tick_timer, 1000)`
- Display as MM:SS with tabular-nums font
- **Reconnect handling:** On mount, if there's an active payment (order exists, payment pending), calculate remaining time from `order.inserted_at` rather than starting fresh at 180. This handles LiveView disconnects on flaky mobile networks.

**Files:** `lib/emakola_web/live/storefront/checkout_live.ex`

## 7. Order Confirmation Page (`OrderConfirmationLive`)

### UI Elements
- Animated green checkmark (CSS @keyframes scale + fade-in)
- "You're all set!" heading with order number subtitle
- "What happens next" card with 3-step vertical timeline:
  1. Order received (green, active) -- "The seller has been notified"
  2. Being prepared (grey, upcoming) -- "We'll SMS you when it ships"
  3. Delivered to you (grey, upcoming) -- "Estimated 2-5 business days"
- Compact order summary: product thumbnail row, total paid
- Shows discount line if `order.discount_amount > 0`
- "View details" expandable for full line items
- "Continue Shopping" primary CTA (link to store home)
- "Contact seller on WhatsApp" secondary CTA (wa.me deep link)
- Note: "We'll text you at +233 XX XXX XXXX with updates"

### Data
- Load order with line_items preloaded
- Need product images for thumbnails -- load via variant_id -> product -> images

**Files:** `lib/emakola_web/live/storefront/order_confirmation_live.ex`

## 8. Files Changed Summary

### New Files
- `lib/emakola/orders/resources/coupon.ex`
- `lib/emakola_web/live/admin/coupon_live.ex`
- `priv/repo/migrations/*_add_coupons_and_order_fields.exs`
- `test/emakola/orders/coupon_test.exs`
- `test/emakola/orders/checkout_service_coupon_test.exs`
- `test/emakola_web/live/storefront/checkout_live_redesign_test.exs`
- `test/emakola_web/live/admin/coupon_live_test.exs`

### Modified Files
- `lib/emakola/cart/cart_store.ex` -- document image_url field
- `lib/emakola/orders/orders.ex` -- register Coupon resource
- `lib/emakola/orders/resources/order.ex` -- add coupon relationship, delivery_fee, discount_amount
- `lib/emakola/orders/checkout_service.ex` -- coupon validation, discount calc, re-validate in transaction
- `lib/emakola_web/live/storefront/product_detail_live.ex` -- include image_url in cart item
- `lib/emakola_web/live/storefront/cart_live.ex` -- product images, mobile summary
- `lib/emakola_web/live/storefront/checkout_live.ex` -- full accordion redesign + coupon UI + rich MoMo state
- `lib/emakola_web/live/storefront/order_confirmation_live.ex` -- celebration redesign
- `lib/emakola_web/router.ex` -- add admin coupon route

## 9. Testing Strategy

Per CLAUDE.md: TDD mandatory, 90% coverage minimum.

### Unit Tests
- `coupon_test.exs`: CRUD actions, identity uniqueness, validation (percentage <= 100%, required fields)
- `checkout_service_coupon_test.exs`:
  - `validate_coupon/3`: active, expired, not started, max uses exceeded, minimum order not met, wrong store
  - `calculate_discount/3`: percentage (with and without max cap), fixed amount (capped at subtotal), free shipping
  - Percentage rounding edge cases (small amounts)
  - Race condition: concurrent usage increment

### Integration Tests
- Full checkout with coupon applied (happy path)
- Checkout where coupon expires between Apply and Place Order (re-validation)
- Checkout with free shipping coupon (delivery fee zeroed)

### LiveView Tests
- Accordion step navigation (forward, back, edit completed step)
- Coupon apply/remove UI in Step 3
- Mobile order summary expand/collapse
- MoMo waiting state rendering with timer
- Cart page with product images

### Admin Tests
- Coupon CRUD (create, edit, deactivate)
- Coupon list with search/filter
- Validation errors (duplicate code, invalid percentage)

## 10. Out of Scope

- Customer accounts/login (stays guest)
- Address book for returning customers
- Tax calculation
- Email confirmation
- Inventory reservation (stock decremented at order creation, existing behavior)
