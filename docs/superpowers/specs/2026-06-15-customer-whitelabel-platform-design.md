# Customer White-Label App Platform — Design (CW1 First Slice + Program)

**Date:** 2026-06-15
**Status:** Approved (design)
**Repo (app):** new sibling repo `~/Projects/emakola_shop` (created during plan execution)
**Backend:** the existing `emakola` Phoenix/Ash app (new public customer API surface)

## What this is

A **white-label, per-store native app platform**: each Emakola merchant gets their **own branded single-store shopping app** (one store per app — *not* a marketplace) — browse that store's products → cart → checkout → mobile-money/Paystack → order tracking. Native **Flutter**, published to both the App Store and Google Play.

This was chosen deliberately over the research doc's PWA recommendation (`docs/mobile-app-research.md`, PR #128), and over a single marketplace app, with the full cost on the table (see Distribution reality). This spec designs the **first build slice**; the full platform is a multi-month, multi-sub-project program.

## 🚨 Distribution reality (researched 2026-06-15 — load-bearing, drives the whole model)

Per-merchant white-label native apps are **viable, but via exactly one compliant path** (confirmed against current Apple guidelines + how Tapcart/Vajro operate):

- **Apple Guideline 4.2.6** rejects apps "created from a commercialized template or app generation service" **unless submitted directly by the provider of the app's content.** So: **each merchant must hold their own Apple Developer account** ($99/yr, **must be a registered legal entity**), and the app ships **under the merchant's identity** — the platform is only an invited App Store Connect delegate that builds/uploads. The "one Emakola account mass-publishes hundreds of apps" model is **banned**. No agency/provider program exists; onboarding is linear, ~3–4 weeks/merchant.
- **Apple Business Manager Custom/Unlisted apps** are NOT a consumer channel (limited audiences only). Apple Enterprise accounts for public distribution = termination. Neither is an option.
- **Google Play** explicitly *permits* per-client white-label (2025 guidance), recommends a **separate account per merchant** (managed model keeps platform admin), more lenient on entity status. Mass-single-account publishing risks mass-suspension.
- **Implication for Emakola specifically:** Apple's legal-entity requirement **excludes unincorporated micro-merchants** — a large slice of the Ghanaian SMB base. Ghana is ~68% Android. This is policy, not something engineering can fix; it is the platform's central operational constraint.

**Consequence for design:** the *engineering* (a themeable single-store app + a per-merchant build pipeline) is identical regardless of accounts. The per-merchant-account/onboarding burden is **operational process**, documented here, not code. CW2's pipeline injects per-merchant config + builds + uploads as a delegate.

## Program decomposition (recorded; only the CW1 first slice is designed in detail)

| Sub-project | What | Notes |
|---|---|---|
| **CW0 — Customer/storefront backend API** | Public single-store browse + product detail (this slice); later cart, checkout, mobile-money/Paystack, customer auth/guest, order tracking | New `ash_json_api` surface over the existing `Emakola.Catalog`/`Orders`/`Payments`. Phase-0-sized over the full program. |
| **CW1 — Themeable single-store Flutter app** | The product that gets multiplied: browse → product → cart → checkout → pay → track, branded entirely by config. **This slice: themeable browse + product detail only.** | Reuses merchant-app stack + review discipline. The config-driven theming is the white-label DNA. |
| **CW2 — Per-merchant build/publish pipeline + onboarding** | Inject per-merchant `AppConfig` → flavored, signed iOS+Android binaries (bundle id, icon, name, theme) → submit under each merchant's own accounts (delegate model) + merchant onboarding | The novel/hard platform half. fastlane + flavors + per-merchant signing. |

**Build order:** CW0 + CW1 first — one real branded store app shopping end-to-end before automating the multiplication (you can't sensibly pipeline-publish an app that doesn't exist). **Cart/checkout/payment (CW0+CW1 buying) and CW2 each get their own spec → plan → build cycle.**

## First slice scope — themeable browse + product detail

**In:** new repo scaffold + CI; the `AppConfig` white-label seam (storeId/slug + branding) driving theme + all API calls; a public store-scoped browse API (store info, product list, product detail); a config-branded catalog UI (home/product list + product detail) for ONE pilot store, against the live API.

**Out (deferred):** customer auth, cart, checkout, payment, order tracking (the buying program); offline cache; pagination polish; **the entire CW2 build/publish/onboarding pipeline**; multi-store anything (it's white-label — one store per app).

## Architecture

### The white-label config (the DNA)

New repo `emakola_shop`, Flutter + Riverpod 3.x, reusing every proven merchant-app pattern: `dio`, `go_router`, the **codegen-gate lesson** (`ash_json_api` → openapi-generator dart-dio **models-only + hand-written repos**; the generated *client* doesn't compile for JSON:API query params), feature-first structure, subagent + two-stage-review build.

Everything that differs per merchant lives in **one typed `AppConfig`**: `storeSlug`, `storeId`, `storeName`, `seedColor`, `logoAsset`. The app is **scoped to ONE store** (`config.storeSlug`) — every API call is for that store; **no cross-store browsing**. `ThemeData` is built *from* `AppConfig` (M3 seed color, app name); the logo is a branded asset.

For the skeleton: **one committed config for a pilot store**, delivered via `--dart-define` + a branding asset. **This `AppConfig` is the exact seam CW2's pipeline injects per-merchant** — designing it as the single clean source of per-merchant variation now is the architectural payoff: the multiplication later becomes "different AppConfig + icon, build."

### CW0 backend slice — public single-store browse API

New **unauthenticated, store-scoped** `ash_json_api` read endpoints under `/api/v1/shop` (distinct from Phase 0's bearer-gated merchant API):

| Endpoint | Returns |
|---|---|
| `GET /api/v1/shop/:store_slug` | Store info — name, branding hints, currency |
| `GET /api/v1/shop/:store_slug/products` | Published+active products, keyset-paginated (image, name, price-from) |
| `GET /api/v1/shop/:store_slug/products/:id` | Product detail — images, description, variants, prices |

- **Reuses the existing `Emakola.Catalog` domain** (Products/Variants/Images) — new *read* JSON:API endpoints over resources that already power the Phoenix storefront. No new data model.
- **Store resolved by slug in the path** (mirrors the web storefront's `/s/:store_slug`); that scopes the query — the tenant boundary. Only **published, active** products are exposed (public-visibility filter, same as the storefront).
- **No auth, no `X-Store-ID`** — the store is the path, browsing is open. (Customer auth + cart are the buying slice, not here.)
- Money: integer minor units (pesewas). Same JSON:API + keyset-pagination shapes the merchant app proved, so the Dart decode patterns carry straight over.
- **Acknowledged tension:** this read-API duplicates what the Phoenix storefront already serves as mobile web — inherent to the native-white-label decision, named here, not a defect.

### Catalog UI + walking skeleton

`features/catalog` in `emakola_shop`:
- **Home / product list** — app bar with the store's name + logo (from `AppConfig`, themed by seed color); product grid/list (image, name, price-from), keyset-paginated, loading/empty/error states.
- **Product detail** — image carousel, name, price, description, variant options.
- **Data flow:** `AppConfig.storeSlug` → `CatalogRepository` (hand-written dio over CW0, JSON:API decode reusing merchant patterns) → Riverpod providers → screens, **painted in the merchant's brand**.

### Error handling

Mirrors the merchant app: typed failures from the `{errors:[…]}` envelope → friendly messages; a slug resolving to no store → a clean "store unavailable" screen (not a crash); offline → retry affordance (cache is a later slice).

### Testing

Same discipline that caught eight bugs on the merchant side: TDD per slice (decode, repositories, widgets), subagent + two-stage review, CI-green. Version-sensitive Flutter/Dart package APIs verified against current pub.dev/context7 at build time (Flutter 3.44/Dart 3.12).

## Walking-skeleton exit criterion

The **pilot store's real products render in a config-branded app** — its name, its colors, its logo in the bar — and tapping a product opens detail, all against the live CW0 API. That single run proves the three things the whole platform rests on: **(1) the theming-by-config seam works, (2) the public browse API works, (3) the Dart API-client patterns carry over.**

## Known limitations / open decisions (for later sub-projects)

- **CW2 onboarding is the real cost** — per-merchant Apple ($99/yr, legal entity) + Play accounts, delegate submission, ~3–4 wk/merchant. The unincorporated-micro-merchant exclusion on iOS is unresolved and may warrant a PWA fallback for the long tail (revisit at CW2).
- Pilot store selection (which real store's catalog to brand the skeleton with) — decide at plan time.
- Branding source: hardcoded `AppConfig` now; later, whether branding is merchant-entered (a backend `store.branding`) and synced, or pipeline-baked — decide when CW2/buying lands.
