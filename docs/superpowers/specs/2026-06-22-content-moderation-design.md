# Content Moderation (Products) — Design

## Context

Platform staff need to take down counterfeit/prohibited merchant **products** across all stores, and reinstate them. Fourth platform-admin backlog item (after store lifecycle #190, KYC #191, impersonation #195); reuses their audit + permission + notify + queue patterns.

**Decisions (with user):** products only in v1 (reviews already have merchant hide/unhide — platform review takedown is a fast-follow); **proactive** takedown (no reporting system exists; the queue is a cross-store product search with a takedown action); reuse `:manage_stores`; field names `moderation_status`/`_reason`/`_at`.

**Key constraint from exploration:** Product visibility is gated by the merchant-owned `status` (`:draft/:active/:archived`); a platform takedown must NOT reuse that field (the merchant could flip it back). So moderation is a **separate platform-owned control** — the same `active`-vs-`status` split as the store-lifecycle feature.

Branch: `feature/store-content-moderation`. TDD throughout.

## Data model — `Catalog.Product` gains platform-owned moderation fields

- `moderation_status` `:atom`, `one_of [:ok, :taken_down]`, `allow_nil? false`, default `:ok`, `public? true`
- `moderation_reason` `:string` (nil when `:ok`)
- `moderation_at` `:utc_datetime_usec`

A product is customer-visible iff `status == :active AND moderation_status == :ok`. Distinct names avoid clashing with the existing merchant `status`.

Migration via `mix ash.codegen add_product_moderation` (NOT NULL default `:ok` backfills existing rows; trim the recurring unrelated snapshot drift — `[[emakola-store-lifecycle]]` lesson). Index `moderation_status` (every storefront read filters it).

## Actions (platform-only)

On `Catalog.Product` (called `authorize?: false` from the platform LiveView):
- `:take_down` — `argument :reason, :string, allow_nil?: false`; set `moderation_status :taken_down`, `moderation_reason`, stamp `moderation_at`.
- `:reinstate` — set `:ok`, clear reason, stamp.

Policy: `policy action([:take_down, :reinstate]) do forbid_if(always()) end` (the existing Product policies only admit Merchant actors for writes; this forbids ALL actors so only `authorize?: false` platform code can run them — merchants can't reverse a takedown). Stamp via a small change module or `set_attribute(&DateTime.utc_now/0)` (proven in lifecycle/KYC). Code interfaces in the Catalog domain (`take_down_product`, `reinstate_product`).

## Enforcement (storefront reads)

Add `and moderation_status == :ok` to the customer-facing Product reads in `product.ex`: `get_by_slug`, `list_related`, `list_by_category`, and any sibling storefront/search read that currently filters `status == :active`. Leave admin/merchant reads untouched. A taken-down product vanishes from the storefront, category pages, related lists, and search; the row stays (restorable). Verify each storefront caller (`ProductListLive`, `ProductDetailLive`, `CategoryLive`, search).

## Platform queue — `/platform/moderation` (`Platform.ModerationLive.Index`)

Gated `on_mount {RequirePermission, :manage_stores}`. Loading-shell (no DB on disconnected mount). New `read :list_for_moderation` on Product (global/cross-store, args: `search`, `status` filter; loads `:store` + primary image; sorted recent). Single LiveView (no detail page):
- Search by title/slug; filter active / taken-down.
- Each row: thumbnail, title, store name, price, a storefront link (works while visible), and **Take down** (reason modal) / **Reinstate** buttons.
- `authorized/2` + `reload_current_user/1` re-check (`:manage_stores`) on every action; reason-modal pattern from `StoreLive.Show`.
- New "Moderation" sidebar nav (`:if` `:manage_stores`), icon `shield`/`flag`.

## Audit + notify

- Atoms `:product_taken_down` / `:product_reinstated` in `PlatformAuditLog` `one_of`; red/green in `audit_log_components.ex`. Metadata `%{"product_id","product_title","store_id","reason"}`.
- New `Emakola.Notifications.Workers.ProductModerationNotificationWorker` (mirror `VerificationStatusNotificationWorker`): load product → store, SMS+email to the store's contacts, propagate delivery errors, idempotent `unique`. Events `:product_taken_down` / `:product_reinstated`. Enqueue from the LiveView after the action + audit.

## Files

- `lib/emakola/catalog/resources/product.ex` (fields, actions, policy, storefront filters) + catalog domain (interfaces)
- migration `add_product_moderation`
- `lib/emakola_web/live/platform/moderation_live/index.ex` (new) + router `:platform` + sidebar nav
- `lib/emakola/accounts/resources/platform_audit_log.ex` (+2 atoms) + `audit_log_components.ex`
- `lib/emakola/notifications/workers/product_moderation_notification_worker.ex` (new)

## Build sequence (tests → impl → green)

1. Product moderation fields + migration + `:take_down`/`:reinstate` + platform-only policy + interfaces → resource tests (actions set fields; reason required; platform-only policy; reinstate clears).
2. Storefront read filters → tests (taken-down product excluded from get_by_slug/list_related/list_by_category; admin reads still include).
3. Audit atoms + colors.
4. `ProductModerationNotificationWorker` + tests.
5. `/platform/moderation` queue + route + nav → LiveView tests (permission gating, search/filter, take down → reason required + sets moderation_status + audit + enqueue, reinstate).
6. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`.

## Verification (end-to-end)

Automated: resource action tests; storefront-exclusion tests; worker test; platform LiveView (`setup_platform_staff` owner + `permissions: [:manage_stores]`; take down sets `moderation_status`, audit row, `assert_enqueued`; reason required; staff without `:manage_stores` redirected). Suite green + format + credo.

Manual: as platform staff open `/platform/moderation`, search a product, Take down with a reason → it disappears from the storefront/category/search; merchant notified; audit entry present; Reinstate → reappears.
