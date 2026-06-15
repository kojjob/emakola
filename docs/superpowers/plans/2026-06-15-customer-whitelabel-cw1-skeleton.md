# Customer White-Label — CW0 Browse API + CW1 Themeable Browse Skeleton — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A pilot store's real products render in a **config-branded** single-store Flutter app (its name/colors/logo), and product detail opens — against a new **public, store-scoped browse API** — proving the white-label theming-by-config seam, the public browse API, and the Dart client patterns.

**Architecture:** Two codebases. (A) **CW0 backend** in the existing `emakola` Phoenix/Ash app: a new public, unauthenticated, store-scoped `ash_json_api` read surface over the existing `Emakola.Catalog` domain — a `PublicStoreTenant` plug resolves `:store_slug` → sets the Ash tenant → an `AshJsonApi.Router` serves the now-tenant-scoped catalog resources (only `status == :active` products). (B) **CW1 Flutter app** in a NEW repo `~/Projects/emakola_shop`, Flutter + Riverpod 3.x, reusing every merchant-app pattern; the white-label DNA is a single typed `AppConfig` driving theme + scoping all API calls to one store.

**Tech Stack:** Elixir/Phoenix 1.8, Ash 3.x, ash_json_api, open_api_spex (backend); Flutter 3.44/Dart 3.12, flutter_riverpod 3.x + riverpod_generator, dio, go_router, openapi-generator dart-dio (models-only), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-06-15-customer-whitelabel-platform-design.md`

---

## ⚠️ Preamble (read first)

- **This plan was authored on deep context; treat its structure/sequence/tests/decision-gates as reliable, and verify version-sensitive package APIs at build time** (ash_json_api DSL, Riverpod 3.x `@riverpod`, go_router redirect, dart-dio flags) against current docs via context7 — exactly as the merchant app did. The compiler + two-stage review are the source of truth over literal syntax.
- **Reuse the merchant app verbatim where possible.** The merchant skeleton plan (`docs/superpowers/plans/2026-06-14-flutter-merchant-app-sp1-skeleton.md`) and the built `~/Projects/emakola_app` are the reference for: the dart-dio **codegen gate** (models-only + hand-written repos; the generated *client* doesn't compile for JSON:API query params — strip the empty-named schema in `gen_api.sh`), the Dio + JSON:API decode pattern, the keyset-pagination cursor parse (`links.next` page[after]), go_router, the CI workflow (format scoped to `lib test`, exclude the generated pkg), and the subagent + two-stage-review discipline.
- **Backend facts (verified) you build on:** Product `status` enum `:draft|:active|:archived` (active = published); Product/Variant/Image attribute-multitenant on `store_id`; **price is `Variant.price` (int minor units)**, surfaced on Product as `min_price`/`max_price` aggregates; Store has `get_by_slug` + `active`, `logo_url`, `currency`; **all four resources already `bypass action_type(:read) do authorize_unless(actor_present()) end`** → nil-actor (public) reads are allowed with NO policy change. `Catalog` domain (`lib/emakola/catalog/catalog.ex`) has NO `AshJsonApi.Domain` yet.

## File structure (target)

**Backend (emakola):**
```
lib/emakola/catalog/catalog.ex                      # + AshJsonApi.Domain ext, json_api prefix
lib/emakola/catalog/resources/product.ex            # + AshJsonApi.Resource, json_api block, :public_list/:public_get actions
lib/emakola/catalog/resources/variant.ex            # + AshJsonApi.Resource, json_api type (included)
lib/emakola/catalog/resources/image.ex              # + AshJsonApi.Resource, json_api type (included)
lib/emakola/stores/resources/store.ex               # + AshJsonApi.Resource, json_api type + :public_get_by_slug
lib/emakola_web/plugs/public_store_tenant.ex        # NEW: resolve :store_slug → Ash tenant (no auth)
lib/emakola_web/shop_api_router.ex                  # NEW: AshJsonApi.Router for the public Catalog surface
lib/emakola_web/router.ex                            # + /api/v1/shop/:store_slug scope + forward
test/emakola_web/controllers/api/shop_*_test.exs    # endpoint + isolation tests
```

**Flutter (~/Projects/emakola_shop):** mirrors the merchant app —
```
lib/core/config/app_config.dart    # the white-label DNA (storeSlug, storeName, seedColor, logoAsset)
lib/core/theme/app_theme.dart      # ThemeData from AppConfig
lib/core/api/{dio_client,json_api}.dart + generated pkg at packages/emakola_shop_api
lib/features/catalog/{product.dart, catalog_repository.dart, product_list_screen.dart, product_detail_screen.dart}
lib/core/router/app_router.dart
lib/main.dart
```

---

# Part A — CW0 backend (in the `emakola` repo, on a feature branch)

### Task A1: Catalog domain + Store/Product/Variant/Image JSON:API declarations

**Files:** `lib/emakola/catalog/catalog.ex`, `resources/product.ex`, `resources/variant.ex`, `resources/image.ex`, `lib/emakola/stores/resources/store.ex`.

- [ ] **Step 1:** Add the JSON:API extension to the Catalog domain — change `use Ash.Domain` → `use Ash.Domain, extensions: [AshJsonApi.Domain]` and add:
```elixir
  json_api do
    prefix("/api/v1/shop")
  end
```
(Verify the prefix interplay with the router forward — match how `Emakola.Orders` does it in `lib/emakola/orders/orders.ex`.)

- [ ] **Step 2:** Add `AshJsonApi.Resource` to each of Product, Variant, Image, Store `extensions:` lists, with a `json_api do type "..." end` block (`product`, `variant`, `image`, `store`). Variant + Image get a `type` + NO routes (they're only serialized as `included`). Make sure the attributes the app needs are `public?(true)`: Product (title, slug, description, status, min_price, max_price), Variant (price, sku, position, available), Image (url, thumbnail_url, medium_url, position, alt_text), Store (slug, name, currency, logo_url, tagline). (Additive — web unaffected.)

- [ ] **Step 3:** `mix compile --warnings-as-errors` — clean. Commit:
```bash
git add lib/emakola/catalog lib/emakola/stores/resources/store.ex
git commit -m "feat(shop): JSON:API extensions on Catalog + Store for the public browse API"
```

### Task A2: Public read actions (active-only, store-tenant-scoped)

**Files:** `resources/product.ex` (actions block), `resources/store.ex`; Test `test/emakola/catalog/public_browse_test.exs`.

- [ ] **Step 1 — failing test:** with a store tenant set, `:public_list` returns only `:active` products of that store (not draft/archived, not other stores'); `:public_get` returns an active product with variants+images loaded; a draft product is not found via `:public_get`.
```elixir
defmodule Emakola.Catalog.PublicBrowseTest do
  use Emakola.DataCase, async: true
  import Emakola.Factory
  require Ash.Query

  test "public_list returns only active products of the tenant store" do
    {_m, store} = create_merchant_with_store!()
    other = create_store!()
    p_active = create_product!(store, %{status: :active})
    _p_draft = create_product!(store, %{status: :draft})
    _p_other = create_product!(other, %{status: :active})

    results =
      Emakola.Catalog.Product
      |> Ash.Query.for_read(:public_list)
      |> Ash.read!(authorize?: false, tenant: store.id)

    assert Enum.map(results, & &1.id) == [p_active.id]
  end
end
```
(Adjust factory calls to the real `create_product!` signature — check `test/support/factory.ex`; `create_product!(store, attrs)` exists. Ensure it can set `status`.)

- [ ] **Step 2:** Run → FAIL (`:public_list` undefined).

- [ ] **Step 3 — implement** on Product:
```elixir
    read :public_list do
      description("Public storefront product list — active only, tenant-scoped, newest first.")
      filter(expr(status == :active))
      prepare(build(sort: [inserted_at: :desc], load: [:min_price, :max_price, :images]))
      pagination(keyset?: true, countable: true, default_limit: 20)
    end

    read :public_get do
      get?(true)
      filter(expr(status == :active))
      prepare(build(load: [:variants, :images, :min_price, :max_price]))
    end
```
On Store add `read :public_get_by_slug` (if `get_by_slug` isn't suitable for json_api's get-by-path — verify; the existing `get_by_slug` filters by slug arg and is `get?`).

- [ ] **Step 4:** Run → PASS. **Step 5:** Commit `feat(shop): public active-only browse read actions`.

### Task A3: `PublicStoreTenant` plug (slug → tenant, no auth)

**Files:** Create `lib/emakola_web/plugs/public_store_tenant.ex`; Test `test/emakola_web/plugs/public_store_tenant_test.exs`.

- [ ] **Step 1 — failing tests:** a valid `:store_slug` path param for an `active` store → sets `Ash.PlugHelpers` tenant to the store id, not halted; unknown slug → 404 JSON:API error; an `active == false` store → 404 (don't serve inactive stores).

- [ ] **Step 2:** Run → FAIL.

- [ ] **Step 3 — implement:** read `conn.path_params["store_slug"]`, resolve via `Emakola.Stores.get_store_by_slug(slug, authorize?: false)` (the existing helper), require `store.active`, then `Ash.PlugHelpers.set_tenant(conn, store.id)` and `assign(:shop_store, store)`. Missing/unknown/inactive → 404 with `application/vnd.api+json` `{errors:[{status:"404",code:"store_not_found"}]}` + halt. NO bearer auth (public).

- [ ] **Step 4:** Run → PASS. **Step 5:** Commit `feat(shop): public store-tenant plug (slug → Ash tenant)`.

### Task A4: Shop API router + route wiring + store-info endpoint

**Files:** Create `lib/emakola_web/shop_api_router.ex`; modify `lib/emakola_web/router.ex`; Test `test/emakola_web/controllers/api/shop_browse_test.exs`.

- [ ] **Step 1 — failing endpoint tests** (`EmakolaWeb.ConnCase`, `put_unique_peer_ip`, `accept: application/vnd.api+json`):
```elixir
test "GET /api/v1/shop/:slug/products lists active products", %{conn: conn} do
  {_m, store} = create_merchant_with_store!(%{slug: "pilot-store"})
  p = create_product!(store, %{status: :active})
  _d = create_product!(store, %{status: :draft})

  conn = conn |> put_unique_peer_ip() |> put_req_header("accept", "application/vnd.api+json")
            |> get("/api/v1/shop/pilot-store/products")

  assert %{"data" => [%{"id" => id, "type" => "product"}]} = json_response(conn, 200)
  assert id == p.id
end

test "unknown store slug → 404", %{conn: conn} do
  conn = conn |> put_unique_peer_ip() |> get("/api/v1/shop/nope/products")
  assert conn.status == 404
end

test "another store's products are not exposed under this slug", %{conn: conn} do
  {_m, store} = create_merchant_with_store!(%{slug: "store-a"})
  other = create_store!()
  _foreign = create_product!(other, %{status: :active})
  _own = create_product!(store, %{status: :active})
  conn = conn |> put_unique_peer_ip() |> put_req_header("accept","application/vnd.api+json")
            |> get("/api/v1/shop/store-a/products")
  assert %{"data" => data} = json_response(conn, 200)
  assert length(data) == 1
end
```

- [ ] **Step 2:** Run → FAIL (no route).

- [ ] **Step 3 — implement** the shop router:
```elixir
defmodule EmakolaWeb.ShopApiRouter do
  @moduledoc "Public, store-scoped JSON:API browse surface (ash_json_api). Tenant set by PublicStoreTenant."
  use AshJsonApi.Router, domains: [Emakola.Catalog], open_api: "/open_api"
end
```
Router (`router.ex`) — a public pipeline + scope:
```elixir
  pipeline :shop_api do
    plug :accepts, ["json"]
    plug EmakolaWeb.Plugs.RateLimiter, limit: 100, window_ms: 60_000
  end

  scope "/api/v1/shop/:store_slug" do
    pipe_through [:shop_api, EmakolaWeb.Plugs.PublicStoreTenant]
    # store-info endpoint (hand-rolled controller OR a Store json_api get) + the catalog forward
    forward "/", EmakolaWeb.ShopApiRouter
  end
```
Verify: ash_json_api's product `index` route maps to `:public_list`, `get` to `:public_get`; the tenant set by the plug scopes them. The `GET /api/v1/shop/:store_slug` store-info route: simplest is a small hand-rolled `ShopController.show` returning the assigned `:shop_store` as JSON (name/slug/currency/logo_url) — add it ABOVE the forward (forward swallows everything; mirror the merchant router's `/stores`-above-forward ordering guard).

- [ ] **Step 4:** Iterate to green. **Step 5:** Regressions `mix test test/emakola/catalog test/emakola_web/live/storefront`. **Step 6:** Commit `feat(shop): public /api/v1/shop/:slug browse endpoints (products, detail, store info)`.

### Task A5: Multi-tenant isolation + OpenAPI spec

- [ ] **Step 1:** Add an isolation test file asserting: products of store B never appear under store A's slug (done partly in A4 — consolidate); a draft/archived product 404s on detail; an inactive store 404s. These are the security invariants.
- [ ] **Step 2:** Verify `mix openapi.spec.json --spec EmakolaWeb.ShopApiRouter --pretty=true` emits a spec covering `/products` + `/products/{id}` (+ store info). This becomes the CW1 client contract. Then `rm` it (generated on demand).
- [ ] **Step 3:** `mix format`, `mix credo --strict` (new files), `mix test test/emakola_web/controllers/api/shop_browse_test.exs`. Commit `test(shop): public browse isolation suite + OpenAPI`.

---

# Part B — CW1 Flutter app (`~/Projects/emakola_shop`)

> Mirror the merchant skeleton plan's Tasks 1–8 structure (scaffold → deps → CI → vendor spec → codegen gate → Dio client → catalog repo → screens). Reuse `~/Projects/emakola_app` as the reference implementation for every shared pattern. Below are the **deltas** specific to the customer app.

### Task B1: Scaffold + deps + CI (mirror merchant Tasks 1–3)
- [ ] `flutter create --org com.emakola --project-name emakola_shop --platforms android,ios ~/Projects/emakola_shop`; git init; baseline green; GitHub repo (ask before creating).
- [ ] Deps (skeleton-lean, like the merchant app): `flutter_riverpod riverpod_annotation dio go_router cached_network_image`; dev: `build_runner riverpod_generator mocktail http_mock_adapter`. (Add `cached_network_image` here — product images are core to a shop UI, unlike the merchant order list. Verify current version.)
- [ ] GitHub Actions CI: `dart format --output=none --set-exit-if-changed lib test` (scoped to `lib test` — the merchant CI learned the hard way that `.` catches generated code), analyze, test. Pin flutter 3.44.x.
- [ ] Commit each.

### Task B2: Vendor the shop OpenAPI spec + codegen gate (mirror merchant Tasks 4–5)
- [ ] Generate from the backend: `mix openapi.spec.json --spec EmakolaWeb.ShopApiRouter --pretty=true`, vendor to `~/Projects/emakola_shop/api/openapi.json`.
- [ ] `tool/gen_api.sh`: strip the stray empty-named schema (ash_json_api quirk — same as merchant), scope to what's needed, run `openapi-generator -g dart-dio --global-property=models,supportingFiles,modelTests=false,modelDocs=false` into `packages/emakola_shop_api`, then `build_runner build`. **Decision gate:** are the generated `Product`/`Variant`/`Image` models usable? (Expected yes, per the merchant gate — same generator, same JSON:API shapes.) Path-dep it; exclude from app `analyze`.
- [ ] Smoke test importing a generated model. Commit.

### Task B3: The white-label `AppConfig` + theming (the DNA — NEW, customer-specific)

**Files:** `lib/core/config/app_config.dart`, `lib/core/theme/app_theme.dart`; Test `test/core/config/app_config_test.dart`, `test/core/theme/app_theme_test.dart`.

- [ ] **Step 1 — failing test:** `AppConfig.fromEnvironment()` reads `--dart-define` values (`STORE_SLUG`, `STORE_NAME`, `SEED_COLOR` as hex, `LOGO_ASSET`) into a typed immutable config with sane fallbacks for local dev (a pilot store). `appTheme(config)` returns a `ThemeData` whose `colorScheme` seed matches `config.seedColor` and `useMaterial3` is true.
```dart
test('AppConfig reads dart-define with fallbacks', () {
  const c = AppConfig.fromEnvironment();
  expect(c.storeSlug, isNotEmpty);            // fallback pilot slug in dev
  expect(c.seedColor, isA<Color>());
});
test('appTheme seeds from config color', () {
  const c = AppConfig(storeSlug:'x', storeName:'X', seedColor: Color(0xFF00695C), logoAsset:'assets/logo.png');
  final t = appTheme(c);
  expect(t.useMaterial3, isTrue);
});
```

- [ ] **Step 2:** FAIL. **Step 3 — implement:** `AppConfig` (const, `fromEnvironment` using `String.fromEnvironment`/`int.fromEnvironment` for the dart-defines + dev fallbacks pointing at the pilot store slug). `appTheme(config)` → `ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: config.seedColor))`. Provide `appConfigProvider` (Riverpod) returning the config.
- [ ] **Step 4:** PASS. **Step 5:** Commit `feat(config): white-label AppConfig + config-driven theme (the per-merchant seam)`.

### Task B4: Dio client (store-scoped base URL) + catalog repo + JSON:API decode

**Files:** `lib/core/api/dio_client.dart`, `lib/core/api/json_api.dart`, `lib/features/catalog/{product.dart,catalog_repository.dart}`; tests.

- [ ] **Step 1 — failing tests:** `decodeProductList(body)` (hand-decode JSON:API `data[]` → domain `Product{id,title,priceFrom,imageUrl}`, reading `min_price` + first image; null-safe); `decodeProduct(body)` (detail + images/variants); `CatalogRepository.list()` issues `GET /api/v1/shop/<config.storeSlug>/products` and decodes. Use `http_mock_adapter` + a captured fixture from the backend's OpenAPI/example.
- [ ] **Step 2:** FAIL. **Step 3 — implement:** `dio_client.dart` builds a `Dio` with `baseUrl` = `<AppConfig.baseUrl>/api/v1/shop/<config.storeSlug>` (store baked into the base path — every call is store-scoped by construction, the white-label invariant); a logging interceptor (debug only). `Product` domain model; `CatalogRepository(dio, config)` with `list({String? pageAfter})` + `get(id)`; `json_api.dart` hand-decodes (reuse the merchant `json_api.dart` approach incl. `links.next` cursor for pagination later). Riverpod providers.
- [ ] **Step 4:** PASS. **Step 5:** Commit `feat(catalog): store-scoped Dio + catalog repository + JSON:API decode`.

### Task B5: Catalog UI (product list + detail) + go_router + main bootstrap

**Files:** `lib/features/catalog/{product_list_screen.dart,product_detail_screen.dart}`, `lib/core/router/app_router.dart`, `lib/main.dart`; widget tests.

- [ ] **Step 1 — failing widget tests:** product-list screen (override the catalog provider) shows the store name in the app bar + a product grid (image via `cached_network_image`, name, formatted price `GHS x.xx` from minor units), with loading/empty/error states; tapping a product navigates to `/products/:id`; detail screen renders images + name + price + description.
- [ ] **Step 2:** FAIL. **Step 3 — implement:** `go_router` (`/` → product list, `/products/:id` → detail — no auth guard, browsing is public); `product_list_screen.dart` (ConsumerWidget watching the catalog provider, branded app bar from `AppConfig`, grid, money formatter — reuse the merchant `_formatMoney`); `product_detail_screen.dart`; `main.dart` (ProviderScope, `MaterialApp.router` with `appTheme(ref.watch(appConfigProvider))`).
- [ ] **Step 4:** PASS; `flutter analyze` clean; `dart format` clean. **Step 5:** Commit `feat(catalog): branded product list + detail + router + bootstrap`.

### Task B6: Walking-skeleton verification (real pilot store)
- [ ] Point `AppConfig` dev fallback at a real pilot store slug; ensure that store has active products + images seeded (seed via the emakola repo if needed). Backend reachable (`emakola.fly.dev` or local).
- [ ] Run the app (web or device) with the pilot `--dart-define`s: confirm the store's **real products render, branded in the store's name/colors**, and product detail opens against the live CW0 API.
- [ ] Optionally re-run with a DIFFERENT `--dart-define` store slug + seed color to **prove the white-label seam** (same binary, different brand + store). Document in a short `WHITELABEL.md`. Commit.

---

## Self-review notes (applied)

- **Spec coverage:** CW0 public browse API (A1–A5: domain/resource json_api, active-only store-tenant-scoped reads, the slug→tenant plug, the router/forward + store-info, isolation + OpenAPI); the `AppConfig` white-label seam (B3); store-scoped Dio + catalog repo + decode (B4); branded catalog UI + walking-skeleton (B5–B6). Cart/checkout/payment/auth/offline + the CW2 pipeline are explicitly out of this slice (per spec).
- **Reuse over re-derivation:** Part B references the merchant skeleton plan + `~/Projects/emakola_app` for shared patterns (codegen gate, Dio/decode, CI, go_router) rather than repeating them — the customer-specific deltas (AppConfig theming, store-baked base URL, cached_network_image, public/no-auth) are spelled out.
- **Public-reads need no policy change** (verified: existing `bypass action_type(:read) authorize_unless(actor_present())`); the tenant is set by the plug, not a header.
- **Route-ordering guard:** the store-info route must sit ABOVE the `forward "/"` (same trap the merchant `/stores` route documented).
- **Version-sensitive Flutter/ash_json_api APIs** carry verify-at-build-time gates (preamble), as the merchant build did.
