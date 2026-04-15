# Launch Features Design Spec

**Date:** 2026-03-27
**Scope:** 7 features for launch readiness
**UI Approach:** Visually distinctive — animations, illustrations, polished empty states

---

## Feature 1: Storefront Search

### What Exists
- `Catalog.search_products!/2` with full-text `:search` action on Product resource
- `CachedCatalog.search_products/2` caching layer
- `ProductListLive` has a search bar with debounce that filters the product list

### What to Build

**Search overlay component** — triggered from nav bar search icon:
- Full-screen overlay on mobile, dropdown panel on desktop
- Live search with debounced input (300ms) calling `CachedCatalog.search_products/2`
- Results show: product thumbnail, title, price, category
- Max 6 results in dropdown, "View all X results" link to product list with search query
- Highlighted matching text in results
- Empty query state: "Start typing to search..." with search illustration
- No results state: illustration + "No products found for '{query}'" + suggested categories
- Keyboard navigation: arrow keys to select, Enter to go, Escape to close

**Search results page** — reuse `ProductListLive` with `?q=` param:
- Already has search functionality, just ensure URL param support for deep linking
- Add result count header: "X results for '{query}'"

**Visual polish:**
- Fade-in animation on overlay open
- Skeleton loading placeholders while searching
- Subtle scale-up on result hover

### Files to Create/Modify
- `lib/emakola_web/components/search_components.ex` — search overlay component
- `lib/emakola_web/live/storefront/product_list_live.ex` — URL param search support
- `lib/emakola_web/components/storefront_components.ex` — add search trigger to nav
- `test/emakola_web/live/storefront/search_test.exs` — search UI tests

---

## Feature 2: Return/Refund Flow

### What Exists
- Orders with status lifecycle (pending → confirmed → processing → shipped → delivered)
- Payment processing with Paystack/Hubtel gateways
- No return/refund resources or UI

### What to Build

**Ash resource: `Orders.Return`**
- Fields: `id`, `order_id`, `customer_id`, `store_id`, `status`, `reason`, `reason_detail`, `admin_notes`, `refund_amount` (integer, minor units), `currency`
- Status enum: `requested`, `approved`, `refunded`, `denied`
- Reason enum: `defective`, `wrong_item`, `not_as_described`, `changed_mind`, `other`
- Actions: `request_return`, `approve`, `deny`, `mark_refunded`
- Validations: order must be in `delivered` status to request return, return window (14 days from delivery)

**Customer-facing:**
- "Request Return" button on account page order detail (only for delivered orders within 14 days)
- Return request modal: reason dropdown, detail textarea, submit button
- Return status display on order detail with timeline visualization
- States: Requested (amber) → Approved/Denied (green/red) → Refunded (blue)

**Admin page: `/admin/returns`**
- Return requests table: order number, customer, reason, date, status badge
- Filters: by status, date range
- Detail view: order info, return reason, approve/deny buttons with notes field
- Approve action triggers refund amount confirmation
- Refund processing: calls gateway refund API, updates return status to `refunded`

**Visual polish:**
- Status timeline with animated progress dots
- Confirmation modal with checkmark animation on successful refund
- Color-coded status badges with subtle pulse on pending items

### Files to Create/Modify
- `lib/emakola/orders/resources/return.ex` — Ash resource
- `lib/emakola/orders/orders.ex` — add Return to domain
- `priv/repo/migrations/*_create_returns.exs` — migration
- `lib/emakola_web/live/storefront/account_live.ex` — add return request UI
- `lib/emakola_web/live/admin/return_live.ex` — admin return management
- `lib/emakola_web/components/return_components.ex` — shared return UI components
- `lib/emakola_web/router.ex` — add admin return route
- Tests for resource, admin page, customer flow

---

## Feature 3: Wishlist/Favorites

### What Exists
- `WishlistLive` — session-scoped wishlist stored in LiveView assigns (not persistent)
- Route at `/s/:store_slug/wishlist`
- Basic add/remove functionality but no database backing

### What to Build

**Ash resource: `Customers.WishlistItem`**
- Fields: `id`, `customer_id`, `product_id`, `variant_id` (optional), `store_id`, `added_at`
- Actions: `add`, `remove`, `list_for_customer`
- Constraint: unique per (customer_id, product_id, store_id)
- For non-logged-in users: keep session-based behavior, prompt to log in to save permanently

**Heart icon on product cards and product detail:**
- Toggleable heart icon with fill animation
- Uses `Phoenix.LiveView.JS` for instant visual feedback
- Sends event to LiveView to persist (if logged in) or update session (if not)
- Heart appears on: product cards in grid, product detail page

**Wishlist page upgrade:**
- Replace session-based with database-backed for logged-in customers
- Grid layout matching product list
- Each item shows: product image, title, price, stock status, "Add to Cart" button, remove (X) icon
- Empty state: illustrated empty heart + "Your wishlist is empty" + "Browse Products" CTA
- Nav badge showing wishlist count

**Visual polish:**
- Heart pulse animation on add (scale up → down with color fill)
- Smooth slide-out animation on remove
- Confetti-like particle burst on first wishlist add

### Files to Create/Modify
- `lib/emakola/customers/resources/wishlist_item.ex` — Ash resource
- `lib/emakola/customers/customers.ex` — add WishlistItem to domain
- `priv/repo/migrations/*_create_wishlist_items.exs` — migration
- `lib/emakola_web/live/storefront/wishlist_live.ex` — rewrite with DB backing
- `lib/emakola_web/components/storefront_components.ex` — heart icon component
- `lib/emakola_web/live/storefront/product_detail_live.ex` — add heart icon
- Tests for resource and LiveView

---

## Feature 4: Order Tracking SMS

### What Exists
- `OrderNotificationWorker` — Oban worker for order lifecycle notifications
- SMS infrastructure: `Emakola.Notifications.SMS` behaviour, `LogSMS` provider
- WhatsApp infrastructure: similar pattern
- Tracking page at `/s/:store_slug/track`

### What to Build

**SMS templates for tracking updates:**
- `confirmed`: "Hi {name}, your order {order_number} has been confirmed! We're preparing it now."
- `processing`: "Good news! Your order {order_number} is being prepared for shipping."
- `shipped`: "Your order {order_number} is on its way! Track it here: {tracking_url}"
- `delivered`: "Your order {order_number} has been delivered. Enjoy!"

**Wire into order status transitions:**
- When `confirm_order`, `process_order`, `ship_order`, `deliver_order` actions fire, enqueue SMS worker
- Only send if customer has phone number and SMS opt-in
- Include tracking URL in shipped SMS

**Store settings:**
- Add `sms_tracking_enabled` boolean to store settings (default: true)
- Admin toggle in settings page

### Files to Create/Modify
- `lib/emakola/notifications/templates.ex` — add tracking SMS templates
- `lib/emakola/notifications/workers/tracking_sms_worker.ex` — Oban worker
- `lib/emakola/orders/orders.ex` — hook into status transition actions
- `lib/emakola_web/live/admin/settings_live.ex` — add SMS toggle
- Tests for worker and template rendering

---

## Feature 5: Coupon Display on Storefront

### What Exists
- Full coupon system: `Orders.Coupon` resource with percentage/fixed/free_shipping types
- Admin coupon management page (`coupon_live.ex`)
- Checkout validates coupons via `CheckoutService`
- Cart page exists at `cart_live.ex`

### What to Build

**Promotion banner on storefront:**
- Animated slide-down banner at top of storefront layout showing active public coupons
- Rotates through multiple active coupons if more than one
- "Use code: SAVE20 for 20% off!" format
- Dismissible with X button, remembers dismissal in session
- Only shows coupons that are: active, within date range, have remaining uses

**Coupon field in cart:**
- Styled input + "Apply" button in cart summary section
- Success state: green checkmark, discount amount shown, code displayed as removable tag
- Error state: red shake animation, "Invalid or expired code" message
- Discount reflected in cart total immediately

**Query for public coupons:**
- Add `list_active_public` action to Coupon resource
- Add `is_public` boolean field to Coupon (default false) — merchants choose which coupons to display publicly
- Existing coupons default to private (enter-code-only)

**Visual polish:**
- Banner slides down with spring animation
- Coupon code in banner uses a "ticket" visual style (dashed border, scissors icon)
- Success confetti micro-animation on apply
- Strikethrough on original subtotal when discount applied

### Files to Create/Modify
- `lib/emakola/orders/resources/coupon.ex` — add `is_public` field, `list_active_public` action
- `priv/repo/migrations/*_add_is_public_to_coupons.exs` — migration
- `lib/emakola_web/components/storefront_components.ex` — promotion banner component
- `lib/emakola_web/live/storefront/cart_live.ex` — add coupon input field
- `lib/emakola_web/live/storefront/store_live.ex` — load active public coupons
- `lib/emakola_web/live/admin/coupon_live.ex` — add public toggle in admin
- Tests for coupon display, apply/remove in cart

---

## Feature 6: Inventory Management Admin Page

### What Exists
- Variant has `stock_quantity` field with `adjust_stock` action
- `list_low_stock/2` query
- Low stock alert workers (email, SMS)
- No dedicated admin inventory page

### What to Build

**Admin page at `/admin/inventory`:**

**Dashboard section (top):**
- Stat cards: Total SKUs, In Stock, Low Stock (< threshold), Out of Stock
- Each card with icon, count, and color coding (green/amber/red)

**Stock table:**
- Columns: Product, Variant (SKU), Current Stock, Status, Actions
- Status badges: "In Stock" (green), "Low Stock" (amber, < 10), "Out of Stock" (red, = 0)
- Sortable by stock level, product name
- Filterable by status (all/in-stock/low/out-of-stock)
- Search by product name or SKU

**Inline editing:**
- Click stock number to edit inline
- +/- buttons for quick adjustment
- "Reason" dropdown on adjustment (restock, sale, damaged, correction)
- Save individual or batch "Save All Changes"

**Stock adjustment log:**
- Modal showing history of adjustments per variant
- Shows: date, previous qty, new qty, reason, who made the change

**Visual polish:**
- Color-coded progress bars showing stock level relative to a threshold
- Animated count transitions on stock updates
- Pulsing dot on out-of-stock items
- Smooth inline edit transitions

### Files to Create/Modify
- `lib/emakola_web/live/admin/inventory_live.ex` — main inventory page
- `lib/emakola_web/components/inventory_components.ex` — inventory UI components
- `lib/emakola_web/router.ex` — add `/admin/inventory` route
- `lib/emakola/catalog/resources/variant.ex` — may need `list_all_variants_with_stock` action
- Tests for inventory page functionality

---

## Feature 7: Store Analytics PDF Export

### What Exists
- Dashboard with Chart.js (revenue, orders, customers)
- Revenue analytics page
- Report pages
- No PDF generation

### What to Build

**PDF generation module:**
- Use server-side HTML-to-PDF approach
- Generate an HTML report template, convert to PDF
- Library: evaluate `chromic_pdf` (uses Chrome headless) or `pdf_generator` (wkhtmltopdf)
- Fallback: generate well-formatted HTML that prints cleanly via browser print

**Report content:**
- Header: store name, logo, date range, generation date
- Revenue summary: total revenue, order count, average order value
- Top 10 products by revenue (table)
- Order status breakdown (table)
- Customer metrics: new vs returning, total customers
- Time-series data: daily/weekly revenue chart (rendered as static SVG or table)

**Export UI:**
- "Export PDF" button on dashboard and report pages
- Date range selector: "This Week", "This Month", "Last 30 Days", "Custom Range"
- Loading state with progress indicator while PDF generates
- Download triggers automatically when ready

**Visual polish:**
- Branded PDF: store colors, clean typography
- Professional layout with sections and dividers
- Button has download icon with subtle bounce animation on hover

### Files to Create/Modify
- `mix.exs` — add PDF library dependency
- `lib/emakola/analytics/pdf_report.ex` — report data aggregation + HTML template
- `lib/emakola_web/live/admin/report_live/index.ex` — add export button + date range
- `lib/emakola_web/controllers/export_controller.ex` — PDF download endpoint
- `lib/emakola_web/router.ex` — add export route
- Tests for report generation

---

## Cross-Cutting Concerns

### Multitenancy
All new resources include `store_id` with attribute-based multitenancy. All queries scoped to store.

### Money
All monetary values stored as integers in minor units (pesewas/kobo). Display formatting in presentation layer only.

### Testing
Each feature includes unit tests for resources/actions and LiveView tests for UI. TDD approach — tests first.

### Animations
Use `Phoenix.LiveView.JS` for client-side animations (transitions, class toggles). CSS animations via Tailwind's `animate-*` utilities and custom `@keyframes` where needed. No JavaScript frameworks.

### Mobile-First
All UI is mobile-first responsive. Touch-friendly targets (min 44px). Optimized for low bandwidth.
