# Mobile App for Emakola — Research & Recommendation

**Date:** 2026-06-12
**Status:** Recommendation — pending decision
**Decision owner:** Kojo

---

## 1. Goal & Constraints

Emakola needs a mobile app strategy. Scoping established:

- **Audience:** Merchants first (order management + push notifications on the go — the Shopify-app equivalent), customers later.
- **Distribution:** Must be in app stores — Google Play **and** Apple App Store. Store presence is a trust/marketing requirement for merchants.
- **Team:** Small, Elixir-focused, with some JS/React experience. Explicit interest in Flutter.
- **Market reality (May 2026, [StatCounter](https://gs.statcounter.com/os-market-share/mobile/ghana)):**
  - Ghana: **68.7% Android / 31.2% iOS** — iOS is a third of the market, not a rounding error.
  - Nigeria: **83.2% Android / 16.6% iOS**.
  - Dominant device class: Transsion (Tecno/Infinix/itel) budget Androids with **2–4 GB RAM**, sub-$150. The MEA region is the world's largest sub-$150 device market.
  - Implication: the app must perform on low-RAM Android **and** ship to the App Store for Ghana's sizeable iPhone base.

## 2. Current State of the Codebase

Emakola is 100% Phoenix LiveView. Mobile-relevant facts:

| Area | State |
|---|---|
| PWA | Solid foundation: `priv/static/manifest.json`, service worker `priv/static/sw.js` (cache-first statics, network-first pages), `offline.html`, tests in `test/emakola_web/pwa_test.exs`. No install prompt, no web push. |
| JSON API | **None.** Only `/api/health` and payment webhooks (`lib/emakola_web/router.ex`). No `ash_json_api`/`ash_graphql`/`cors_plug` in `mix.exs`. The `:api` pipeline exists with rate limiting. |
| Auth | Session-cookie only, but **AshAuthentication tokens are already enabled** on both `Emakola.Accounts.User` (merchants/staff) and `Emakola.Customers.Customer` (store-scoped), with token resources and `require_token_presence_for_authentication?(true)`. The rate limiter already parses Bearer tokens. Merchant login is password-only (TOTP is enforced only for platform staff at the web layer). |
| Push | **None.** Notifications are outbound WhatsApp/SMS/email. No FCM/APNs, no device-token storage. |
| Mobile web UI | Storefront is mobile-first (bottom nav, touch targets, SVG icons, low-bandwidth conscious). |

**Key implication:** any native client requires building a new backend interface layer — JSON API + bearer-token auth endpoints + push. That work is framework-agnostic, reusable for both the merchant and customer apps, and is roughly as large as the first app itself. The frontend framework choice matters less than getting this layer right.

## 3. Candidate Architectures

### 3.1 LiveView Native — ruled out

The appeal was maximal reuse of existing LiveView code. The June 2026 evidence kills it:

- Main `live_view_native` Elixir repo **archived Feb 10, 2026** ([github.com/liveview-native](https://github.com/liveview-native)); stable release stuck at 0.3.1 (Oct 2024) with 0.4.0 in RC for months ([hex.pm](https://hex.pm/packages/live_view_native)).
- Android (Jetpack) client is early-stage: ~110 open issues, low activity — not production-ready for our Android-majority market.
- **No offline support** ("you can't even launch the app without a connection" — [issue #71](https://github.com/liveview-native/live_view_native/issues/71)); no push notification story. Both are dealbreakers for merchants on West African networks.
- Zero known third-party production apps; community sentiment is "watching, not using" ([ElixirForum, May 2025](https://elixirforum.com/t/is-liveview-native-realistic-in-2025/70969)).

**Verdict: No.** Revisit only if the project ships a stable 1.0 with Android parity and offline support.

### 3.2 PWA + TWA wrapper — fails the merchant requirement, wins the customer phase

- **Apple App Store:** Guideline 4.2 treats web wrappers as "web clippings"; pure PWA wrappers are rejected ([Apple guidelines](https://developer.apple.com/app-store/review/guidelines/)). Fails the must-be-in-both-stores constraint for the merchant app.
- **Google Play:** TWA remains officially supported with quality requirements (Lighthouse ≥ 80, Digital Asset Links, offline handling) ([Android docs](https://developer.android.com/develop/ui/views/layout/webapps/trusted-web-activities)).
- **For customers** this is the right-sized answer: storefronts are already mobile-first PWAs in embryo. Adding web push (`web_push_ex` v0.2.0, active — [hex.pm](https://hex.pm/packages/web_push_ex)) and an install prompt gives buyers an app-like experience without Emakola building/distributing a native shopping app per store.

**Verdict: Not for merchants; the default plan for the customer phase.**

### 3.3 Flutter + Phoenix JSON API — recommended

- Flutter 3.41 (Feb 2026), quarterly cadence held through 2025 despite the 2024 layoffs; Google ships its own products on it ([state of Flutter 2026](https://devnewsletter.com/p/state-of-flutter-2026/)).
- **Impeller renderer is default on Android** with OpenGL fallback for older devices; ~100 MB lower memory use vs Skia and consistent 60 fps — material on 2–4 GB RAM devices ([Flutter docs](https://docs.flutter.dev/perf/impeller)).
- Benchmarks (general, not low-end-specific): faster cold start (<200 ms vs 300–400 ms), lower CPU under load than RN; larger bundles (38–42 MB vs 28–32 MB).
- **West African developer ecosystem:** strong Flutter community presence and job-board signal in Ghana/Nigeria; regional hiring slightly favors Flutter even though RN has ~6× more listings globally.
- Costs: Dart ramp-up (≈1–2 weeks from TypeScript; 4–6 weeks to full productivity), no over-the-air code push (Google explicitly isn't investing in it).

### 3.4 React Native (Expo) + Phoenix JSON API — credible runner-up

- RN 0.84 (Feb 2026): New Architecture and Hermes V1 are defaults; legacy architecture removed ([reactnative.dev](https://reactnative.dev/blog/2026/02/11/react-native-0.84)). Expo EAS gives hosted builds, store submission, and **OTA updates** — genuinely valuable when store reviews take 1–7 days.
- Team fit: stays in JS/React; 2–3 weeks to productivity.
- Trade-offs: higher CPU/slower start on low-end Android than Flutter (evidence is general-class, not sub-3 GB specific); thinner regional hiring pool.

### Decision matrix

| Criterion (weight) | Flutter | React Native | LVN | PWA/TWA |
|---|---|---|---|---|
| Both app stores | ✅ | ✅ | ⚠️ iOS only, beta | ❌ App Store |
| Low-end Android perf | **Best** | Good | Unknown | Good |
| Team ramp today | 4–6 wks | **2–3 wks** | Elixir-native | None |
| Ghana/Nigeria hiring pool | **Best** | Good | Tiny | n/a |
| Backend work needed | API+auth+push | API+auth+push | None extra | Web push only |
| Offline capability | ✅ | ✅ | ❌ | Partial |
| OTA fix path | ❌ | **✅ EAS Updates** | n/a (server-driven) | ✅ (it's the web) |
| Project risk | Low | Low | **High** (archived core) | Low |

## 4. Recommendation

**Build the merchant app in Flutter, on top of a new `ash_json_api`-powered API layer. Serve customers with the existing PWA, upgraded with web push and TWA Play-Store packaging.**

Why Flutter over React Native (it's close):

1. **The market is the tiebreaker.** Low-end Android performance and the Ghana/Nigeria Flutter hiring pool matter for the next five years; the team's JS familiarity advantage matters for the next two months.
2. **The app will be thin.** With business logic living in Phoenix/Ash behind the API, the mobile client is mostly screens and push handling — reducing both the Dart ramp-up cost and the value of RN's code sharing with web (which Emakola, being LiveView, doesn't have anyway).
3. **It's the user-preferred stack**, and there is no evidence-based reason to override that preference — RN's main edges (faster ramp, OTA updates) are conveniences, not strategic.

Mitigations for Flutter's weaknesses: no OTA → keep the client thin and lean on the server for copy/config; before committing UI patterns, smoke-test cold start and scroll FPS on a 3–4 GB Tecno/Infinix device (no published sub-3 GB benchmarks exist for either framework).

### Backend stack (Phase 0 choices, evidence-backed)

| Concern | Choice | Evidence |
|---|---|---|
| API | **`ash_json_api`** v1.6.6 (May 2026) — JSON:API endpoints + OpenAPI spec generated from existing Ash resources; supports attribute multitenancy via `Ash.PlugHelpers.set_tenant/2` | [hex.pm](https://hex.pm/packages/ash_json_api), [OpenAPI docs](https://hexdocs.pm/ash_json_api/open-api.html) |
| Auth | **AshAuthentication bearer tokens** (already enabled on `User`/`Customer`) + 2–3 hand-rolled controllers for sign-in/refresh — the community-standard combo. Short-lived access token + custom refresh token (not built-in) | [tokens guide](https://hexdocs.pm/ash_authentication/tokens.html), [refresh pattern](https://www.mikewilson.dev/posts/refresh-tokens-with-ash-authentication/) |
| Push | **Pigeon v2.0.1** (FCM HTTP v1 + APNs, Goth for Google OAuth2) + new `DeviceToken` Ash resource | [hex.pm](https://hex.pm/packages/pigeon) |
| Customer web push (Phase 2) | **`web_push_ex`** v0.2.0 | [hex.pm](https://hex.pm/packages/web_push_ex) |
| GraphQL | Not now — `ash_graphql` is mature (v1.9.4) but adds client complexity the merchant app doesn't need | [hex.pm](https://hex.pm/packages/ash_graphql) |

Tenant resolution in the API follows the existing pattern: merchant's store derived from their org membership (`User` → `Membership` → `Organisation` → store), set as Ash tenant per request — same isolation rules as the web layer.

## 5. Roadmap

### Phase 0 — API foundation (backend only, ~3–5 weeks)
The reusable layer everything else stands on.

1. Add `ash_json_api`; expose read-only merchant endpoints for `Emakola.Orders` (list/detail) under `/api/v1`, tenant-scoped, behind the existing rate limiter.
2. Auth endpoints: `POST /api/v1/auth/sign_in` (AshAuthentication password → access + refresh tokens), `POST /api/v1/auth/refresh`, `DELETE /api/v1/auth/sign_out` (revocation via existing token resources).
3. `DeviceToken` resource (user_id, platform, fcm_token, last_seen_at) + registration endpoint.
4. Push pipeline: Pigeon + Goth; an Oban worker (idempotent, per existing worker conventions) that fires FCM/APNs on order creation alongside the existing WhatsApp/SMS notifications.
5. OpenAPI spec generation wired up (`mix openapi.spec.json`) — this becomes the contract for the Flutter client.
6. **Product-write endpoints** (required by Phase 1 item 5 — the merchant app cannot add products without these): `POST /api/v1/products` (create → default `track_inventory: false` variant + activate, mirroring `Admin.ProductLive.Form` / `Catalog.CsvImporter`), `POST /api/v1/products/:id/variants`, and **multipart `POST /api/v1/products/:id/images`** (stream to Tigris via `Emakola.Storage`, create `Catalog.Image`). Tenant-scoped, behind the rate limiter. The photo-first bulk flow is N calls to these per batch — no separate bulk endpoint needed for MVP.

**Exit criteria:** integration-tested API (multi-tenant isolation tests mandatory); push notification demonstrably delivered to a test device on new-order creation; **a product created via the API with an uploaded image appears live, sellable, with its image on the storefront** (the same end-to-end check used for the web flows).

### Phase 1 — Merchant app MVP (Flutter, ~6–8 weeks)
1. Flutter project + CI (build, test; store delivery via fastlane or Codemagic — decide then).
2. Login (email + password → tokens, secure storage), store context display.
3. Orders list + order detail + status updates (the existing `Admin.OrderLive` flows, reshaped for mobile).
4. Push notifications for new orders — the killer feature; deep-link from notification to order detail.
5. **Product management — add/edit + bulk add.** Build mobile parity for the web product flows
   (shipped on web 2026-06, all live in prod):
   - **Photo-first bulk add — port this first; it was designed for the phone.** Pick many photos
     from the gallery at once → a card per photo with big Name + Price inputs → publish all as
     live, sellable products. For low-literacy merchants this is the natural way to stock a store
     from a phone. Web: `Admin.ProductLive.BulkPhoto`; spec
     `docs/superpowers/specs/2026-06-13-bulk-photo-upload-design.md` (PRs #137, #138).
   - **Single product add** — title + price (→ a `track_inventory: false` default variant, sellable
     immediately) + image upload. Web: `Admin.ProductLive.Form`.
   - **CSV bulk import with images** — desktop-oriented (a spreadsheet + filename-matched photos);
     the API should expose it but the Flutter UI can defer past MVP. Web: `Catalog.CsvImporter`;
     spec `docs/superpowers/specs/2026-06-14-csv-bulk-import-design.md` (PR #139).
   - ⚠️ **API dependency — now a concrete Phase 0 task (item 6 above):** the merchant app needs
     product-create + variant + multipart image-upload endpoints, which the order-centric Phase 0
     API does not yet have. They are sequenced ahead of this item and gated by the Phase 0 exit
     criteria.
6. Ship to Play (internal track) and TestFlight; then store listings.

**Exit criteria:** a merchant can hear about, view, and action a new order from their phone within
seconds of checkout, **and stock their store by snapping product photos** (photo-first bulk add).

### Phase 2 — Customer answer (PWA upgrade, ~2–3 weeks)
1. Web push for order status updates (`web_push_ex` + service-worker push handler).
2. Install prompt + manifest polish (shortcuts, richer icons).
3. Package the storefront as a TWA for Play Store (Bubblewrap/PWABuilder; Lighthouse ≥ 80) — decide then whether it's one Emakola marketplace app or per-store apps.

### Phase 3 — Expand (later, demand-driven)
- Merchant app: inventory management, product editing, dashboard analytics.
- Customer native app (Flutter, reusing Phase 0 API patterns) only if PWA metrics show demand TWA can't satisfy.
- Platform-staff features stay web-only (TOTP/session model doesn't translate cleanly to mobile and there's no need).

## 6. Open Questions (deferred decisions)

1. **Customer-phase shape:** one Emakola marketplace app vs per-store TWA apps — decide with merchant feedback during Phase 2.
2. **iOS distribution cadence:** Apple review adds friction for a fast-moving MVP; consider TestFlight-first beta with merchants.
3. **Offline depth for merchants:** Phase 1 ships read-cache offline (view recent orders); offline mutations (status changes queued) are a Phase 3 call.
4. **Sub-3 GB device performance:** no published benchmarks exist — validate on real Tecno/Infinix hardware during Phase 1 week 1.

## Appendix: Source quality notes

Market share figures are StatCounter May 2026 (authoritative). Framework version/release claims verified against official sources (hex.pm, reactnative.dev, docs.flutter.dev, github.com/liveview-native). Performance comparisons are community benchmarks (medium trust) — none cover the sub-3 GB RAM device class, hence the Phase 1 hardware validation requirement.
