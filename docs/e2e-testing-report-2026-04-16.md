# E2E Testing Report — 2026-04-16

## Test Plan

Tested all core user journeys across desktop (1280x800) and mobile (375x812) using Playwright MCP against the live Phoenix dev server.

## Flows Tested (18 Playwright tests + manual Playwright MCP testing)

| Flow | Status | Notes |
|------|--------|-------|
| **Landing page** | Pass | Hero, features, pricing, testimonials, footer render correctly |
| **Merchant login (valid)** | Pass | Redirects to `/dashboard` with "Welcome back" flash |
| **Merchant login (invalid)** | Pass | Shows "Invalid email or password" error flash |
| **Merchant registration** | Pass | Form renders with all fields |
| **Admin dashboard** | Pass | Metrics (revenue, orders, customers, avg order) display |
| **Admin navigation** | Pass | Products, Orders, Settings all load correctly |
| **Admin product list** | Pass | Shows 6 products with images, status, stock |
| **Storefront home** | Pass | Hero, featured products, newsletter, footer |
| **Product listing** | Pass | 5 active products, categories sidebar, search |
| **Product detail** | Pass | Image, description, variants, Add to Bag, WhatsApp link |
| **Add to cart** | Pass | Flash confirmation "Added to cart" |
| **Cart page** | Pass | Item details, order summary, promo code, checkout link |
| **Checkout** | Pass | Contact, shipping, delivery, payment methods, Place Order |
| **Mobile storefront** | Pass | Responsive single-column layout |
| **Mobile cart** | Pass | Stacked layout, prominent checkout button |
| **Mobile login** | Pass | Full-width form, mobile brand header |
| **Mobile dashboard** | Pass | Hamburger menu, 2-col metric grid |

## Bugs Found & Fixed

| Bug | Severity | File | Fix |
|-----|----------|------|-----|
| **Login flash messages not rendered** | High | `lib/emakola_web/live/auth/login_live.ex` | Added flash message rendering (`role="alert"`) — page used `layout: false` but never rendered flashes |
| **Register flash messages not rendered** | High | `lib/emakola_web/live/auth/register_live.ex` | Same fix — added inline flash rendering |
| **Duplicate migration files** | Medium | `priv/repo/migrations/` | Removed 3 macOS Finder duplicate files (`" 2.exs"`) that blocked `mix ecto.migrate` |

### Root Cause: Flash Messages

Both merchant auth pages (`login_live.ex`, `register_live.ex`) use `layout: false` in their `mount/3` callback, which opts out of the root layout. The root layout normally renders flash messages via `<.flash_group>`. Since these pages didn't render flashes in their own templates, all `put_flash/3` calls (invalid credentials, rate limiting, success messages) were silently swallowed.

**Fix:** Added inline flash message rendering directly in each template, before the form element:

```heex
<div :if={@flash["error"]} class="mb-4 flex items-center gap-2 rounded-xl bg-red-50 border border-red-200 px-4 py-3 text-sm text-red-700" role="alert">
  <span class="material-symbols-outlined text-lg text-red-500">error</span>
  <span>{@flash["error"]}</span>
</div>
```

## Console Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| `ChartHook` "unknown hook" errors (x4) | Low | Dashboard charts don't render; chart.js hook registered correctly but may have bundling issue |
| Deprecated `apple-mobile-web-app-capable` meta tag | Info | Browser-level warning, not in source code |

## Playwright E2E Test Suite

Tests are located in `e2e/` with the following structure:

```
e2e/
  package.json
  playwright.config.ts
  tests/
    auth.spec.ts          # 4 tests: login page, error flash, successful login, register page
    admin.spec.ts         # 2 tests: dashboard metrics, admin pages load with content
    storefront.spec.ts    # 7 tests: home, products, product detail, categories, about, blog, footer
    cart-checkout.spec.ts  # 5 tests: add to cart, cart contents, checkout form, empty cart, continue shopping
```

### Running Tests

```bash
cd e2e
npm install
npx playwright install chromium
npx playwright test --project=desktop-chrome
```

### Key LiveView Testing Notes

- Use `waitForLoadState("networkidle")` before interacting with LiveView-powered buttons (phx-submit, phx-click) — the websocket must connect before these handlers are active
- Use `waitForURL` with glob patterns for redirect chains (LiveView -> controller -> destination)
- Target flash messages with `#flash-info` or `#flash-error` IDs rather than generic `[role=alert]` since Phoenix renders multiple hidden alert elements
- Reduce parallel workers (`workers: 2`) to avoid overwhelming the dev server

## Remaining Risks

1. **Dashboard charts** — `ChartHook` errors mean revenue/order trend charts are blank. The hook and chart.js are wired up correctly; likely needs an `esbuild` rebuild or chart.js version compatibility check
2. **Auth session redirect timing** — The LiveView -> `/auth/session` -> `/dashboard` redirect chain is occasionally slow under concurrent load (seen in Playwright parallel workers). Not a user-facing issue but could affect automated testing
3. **No `phx-change` live validation** on login/register forms — validation only happens on submit, not as users type
4. **Customer auth pages** — Customer login (`/s/:store_slug/login`) and registration were not tested in this session; they use the standard layout so flash messages should work, but should be verified
