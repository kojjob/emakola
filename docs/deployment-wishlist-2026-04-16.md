# Emakola Deployment Wishlist — 2026-04-16

Deep codebase review before production deployment. Issues ranked by severity.

---

## BLOCKERS — Must fix before deploying

### 1. Release scripts don't exist — deploy will crash on boot
- **Files:** `mix.exs`, `Dockerfile`, `fly.toml`
- **Issue:** No `releases` block in mix.exs. Dockerfile copies from `rel/overlays/bin/` which doesn't exist. `fly.toml` runs `/app/bin/migrate` as release command — will fail.
- **Fix:** Run `mix phx.gen.release` to generate `rel/overlays/bin/server` and `rel/overlays/bin/migrate`, add releases config to mix.exs.

### 2. Product images saved to local disk — wiped on every deploy
- **File:** `lib/emakola_web/live/admin/product_live/index.ex:1526-1551`
- **Issue:** `save_uploaded_images` writes to `priv/static/uploads/`. Container deploys wipe the filesystem. All merchant product images vanish.
- **Fix:** Wire up the existing `lib/emakola/storage/s3.ex` module for production uploads. Use S3/DigitalOcean Spaces with CDN.

### 3. ETS cart store — server restart loses all active carts
- **File:** `lib/emakola/cart/cart_store.ex`
- **Issue:** Carts stored in ETS (volatile memory). No supervised owner — if the Application process crashes, ETS table dies. `cleanup_expired/1` exists but is never called, so carts accumulate without bound.
- **Fix (short-term):** Add a GenServer owner for the ETS table in the supervision tree. Add an Oban cron job to run `cleanup_expired/1` every 6 hours.
- **Fix (long-term):** Persist carts to PostgreSQL for durability across deploys.

### 4. Checkout creates payment record without checking the result
- **File:** `lib/emakola_web/live/storefront/checkout_live.ex:1352-1363`
- **Issue:** `Ash.create()` return value is discarded. If the DB write fails (e.g., duplicate gateway_reference from double-click), the order proceeds with no payment record — a financial reconciliation disaster.
- **Fix:** Pattern match on `{:ok, payment}` / `{:error, reason}` and handle failure.

### 5. RESEND_API_KEY not guarded in runtime.exs
- **File:** `config/runtime.exs:41`
- **Issue:** Missing `|| raise` guard. If env var is unset, first email send silently fails.
- **Fix:** `api_key: System.get_env("RESEND_API_KEY") || raise "RESEND_API_KEY not set"`

---

## HIGH — Will cause failures at scale

### 6. N+1 query bomb in Review.eligible? — runs on every product page
- **File:** `lib/emakola/catalog/resources/review.ex:148-187`
- **Issue:** For each delivered order, fires a separate query to check line items. Customer with 20 orders = 22 queries on every PDP visit.
- **Fix:** Single join query: orders -> line_items -> variants.

### 7. Dashboard loads all line items into memory for "Top Products" chart
- **File:** `lib/emakola_web/live/dashboard/dashboard_helpers.ex:270-294`
- **Issue:** No LIMIT on LineItem query. "All time" on a store with 10k orders loads 30k structs, groups in memory. Repeats every 30-second refresh.
- **Fix:** DB-level `GROUP BY product_title` aggregate query with LIMIT 5.

### 8. All admin list pages load unbounded result sets — no pagination, no streams
- **Files:** `admin/order_live/index.ex`, `admin/customer_live/index.ex`, `admin/product_live/index.ex`
- **Issue:** Zero LiveViews use `stream/3`. Every list is a plain assign. 500+ orders = 500 structs in LiveView heap, full re-diff on every filter change.
- **Fix:** Add Ash pagination (`offset` or `keyset`) and LiveView streams for all list pages.

### 9. Product listing loads ALL products then takes 12 in Elixir
- **File:** `lib/emakola_web/live/storefront/product_list_live.ex:180-183`
- **Issue:** `list_products_by_store_and_status!` returns all active products, then `Enum.take(12)`. Store with 10k products loads them all.
- **Fix:** Add `Ash.Query.limit(12)` to the query action.

### 10. Order search filters in-memory after loading all orders
- **File:** `lib/emakola_web/live/admin/order_live/index.ex:291-317`
- **Issue:** `Enum.filter` on order_number after fetching all rows. Must be a DB query with `ilike`.

### 11. LowStockAlertWorker queries ALL stores with no pagination
- **File:** `lib/emakola/inventory/workers/low_stock_alert_worker.ex:37-43`
- **Issue:** Loads every store, then each store's variants in separate queries. 100 stores = 200+ queries.
- **Fix:** Single cross-store query filtered by `track_inventory and stock_quantity < threshold`.

### 12. WebhookDeliveryWorker stores webhook secret in Oban job args
- **File:** `lib/emakola/webhooks/workers/webhook_delivery_worker.ex:8-20`
- **Issue:** Secrets visible in `oban_jobs` table, logs, dashboards.
- **Fix:** Fetch secret from `outbound_webhooks` table at execution time by `webhook_id`.

---

## MEDIUM — Correctness and reliability issues

### 13. String.to_existing_atom on user input in 8+ locations
- **Files:** `order_notification_worker.ex:29`, `category_live.ex:73`, `account_live.ex:103`, `design_live.ex:40`, `coupon_live.ex:791`, `theme_live.ex:810`, `media_live/index.ex:29`, `post_live/form.ex:80`
- **Issue:** Raises `ArgumentError` if atom doesn't exist. Crashes LiveView or Oban worker.
- **Fix:** Replace with explicit allow-list pattern match.

### 14. Coupon usage increment is not atomic — race condition
- **File:** `lib/emakola/orders/checkout_service.ex:234`
- **Issue:** Validate-then-increment pattern. Two concurrent checkouts can both pass the `max_uses` check before either commits.
- **Fix:** `SELECT ... FOR UPDATE` on coupon row, or DB CHECK constraint `uses_count <= max_uses`.

### 15. Dashboard queries block the socket synchronously
- **File:** `lib/emakola_web/live/dashboard_live.ex:59-74`
- **Issue:** 8+ DB queries in mount path, wrapped in bare `try/rescue` that masks errors as `default_data()`.
- **Fix:** Use `assign_async` for skeleton-first loading.

### 16. StoreCache invalidation does full ETS table scan
- **File:** `lib/emakola/cache/store_cache.ex:152-168`
- **Issue:** `:ets.foldl` iterates every cache entry to find matching store_id. O(n) on every product save.
- **Fix:** Structure cache keys as tuples `{store_id, resource}` and use `:ets.match_delete`.

### 17. OrderNotificationWorker unique window too short
- **File:** `lib/emakola/notifications/workers/order_notification_worker.ex:16-18`
- **Issue:** 60-second dedup window. Same `order_placed` event 61 seconds later sends duplicate SMS.
- **Fix:** `unique: [period: :infinity, keys: [:order_id, :event]]`

### 18. PaystackWebhookHandler silently swallows all notification errors
- **File:** `lib/emakola/payments/workers/paystack_webhook_handler.ex:109-115`
- **Issue:** Bare `rescue _ -> :ok` around notification dispatch. Hides infrastructure failures.
- **Fix:** Remove rescue, let dispatcher handle its own errors.

### 19. Checkout uses fake email for guest customers
- **File:** `lib/emakola_web/live/storefront/checkout_live.ex:1355`
- **Issue:** `"#{phone}@checkout.emakola.com"` sent to Paystack. Merchants see garbage emails in reconciliation.
- **Fix:** Use a dedicated `customer_phone` field or make email optional with Paystack API.

### 20. Missing FK constraint on line_items.store_id
- **File:** `priv/repo/migrations/20260322163940_create_orders.exs:102`
- **Issue:** Plain `:uuid` column, no `references(:stores)`. Bad store_ids silently accepted.
- **Fix:** Add migration with FK constraint.

### 21. Missing index on orders.coupon_id
- **File:** `priv/repo/migrations/20260326012545_add_coupons_and_order_fields.exs:27`
- **Fix:** Add `create index(:orders, [:coupon_id])` migration.

---

## LOW — Code quality and cleanup

### 22. ImageProcessorWorker generates fake URLs
- **File:** `lib/emakola/workers/image_processor_worker.ex`
- **Issue:** Appends `_thumb` and `_medium` to filename without actual processing. All thumbnails are broken links.

### 23. billing/workers/payment_handler.ex is a no-op placeholder
- **File:** `lib/emakola/billing/workers/payment_handler.ex`
- **Issue:** Returns `:ok` without processing. If webhooks route here accidentally, orders stay pending.

### 24. GscSyncWorker bare pattern match will crash on real API errors
- **File:** `lib/emakola/analytics/workers/gsc_sync_worker.ex:16`
- **Issue:** `{:ok, data} = fetch_gsc_data(org_id)` — `MatchError` when API returns `{:error, _}`.

### 25. Duplicate assign in StoreLive.mount
- **File:** `lib/emakola_web/live/storefront/store_live.ex:36,40`
- **Issue:** `public_coupons` assigned twice. Harmless but indicates copy-paste drift.

### 26. CSP is report-only mode
- **File:** `lib/emakola_web/plugs/content_security_policy.ex:37`
- **Issue:** Uses `content-security-policy-report-only` — violations are logged but not enforced.
- **Fix:** Switch to `content-security-policy` after verifying no false positives.

### 27. Remove localhost exclusion from force_ssl
- **File:** `config/prod.exs:22-25`
- **Issue:** Excludes `localhost` and `127.0.0.1` from SSL — unnecessary on Fly.io.

---

## Deployment Checklist

```
BEFORE FIRST DEPLOY:
[ ] Run mix phx.gen.release — create release scripts
[ ] Wire S3 uploads in product_live/index.ex — test with real bucket
[ ] Guard RESEND_API_KEY in runtime.exs
[ ] Fix checkout payment create — handle error tuple
[ ] Add cart cleanup Oban cron job
[ ] Add LIMIT to product list queries (product_list_live, cart_live)
[ ] Fix Review.eligible? N+1 query
[ ] Add dashboard_helpers aggregate query for top products
[ ] Run mix release locally — verify it builds

BEFORE SCALING (50+ merchants):
[ ] Add pagination to all admin list pages
[ ] Convert admin lists to LiveView streams
[ ] Move order search to DB-level ilike query
[ ] Fix LowStockAlertWorker to single cross-store query
[ ] Add coupon_id index migration
[ ] Add line_items.store_id FK constraint
[ ] Fix coupon usage race condition (SELECT FOR UPDATE)
[ ] Replace String.to_existing_atom with pattern match (8 locations)
[ ] Remove webhook secret from Oban job args
[ ] Persist carts to PostgreSQL

BEFORE GA (general availability):
[ ] Switch CSP from report-only to enforced
[ ] Implement real ImageProcessorWorker with S3
[ ] Add assign_async to dashboard mount
[ ] Fix StoreCache invalidation to use structured keys
[ ] Add DB CHECK constraints for business logic
[ ] Remove payment_handler.ex placeholder or wire it up
[ ] Add comprehensive E2E tests for checkout + payment flow
```

---

## What's Good

- **Multi-tenancy**: store_id filtering is consistent across Ash resources
- **Auth**: AshAuthentication with proper password hashing, session tokens
- **Rate limiting**: Covers auth, API, and webhook endpoints
- **Health check**: `/api/health` verifies DB connectivity
- **Dockerfile**: Solid multi-stage build with non-root user
- **Test coverage**: 1841 tests, good coverage of domain logic
- **Error pages**: Custom 404/500 with proper styling
- **SEO**: Meta tags, structured data, canonical URLs
- **PWA**: Service worker, manifest, offline page
- **Webhook security**: Paystack signature verification implemented
