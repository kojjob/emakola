# Mobile API Phase 0 — Backend Foundation Design

**Date:** 2026-06-12
**Status:** Approved
**Context:** Phase 0 of the mobile app roadmap (`docs/mobile-app-research.md`, PR #128). The reusable API layer the Flutter merchant app (Phase 1) stands on.

## Goal

A bearer-token-authenticated, tenant-scoped JSON:API under `/api/v1` exposing merchant order management, plus a device-token registry and an FCM push pipeline that fires on new orders. OpenAPI spec generation provides the contract for the Flutter client.

## Decisions (with rationale)

1. **`ash_json_api` for resource endpoints; hand-rolled controllers only for auth.** Generated JSON:API + OpenAPI from existing Ash resources; policies and multitenancy enforced at the resource layer we already trust. Hand-rolled-everything was rejected (duplicates serialization/pagination/spec and drifts); GraphQL was rejected in the research doc.
2. **The API authenticates `Merchant`, not `User`.** The research doc predates PR #127's split: `User` is now platform staff; merchants are `Emakola.Accounts.Merchant` (password strategy + `Emakola.Accounts.Token` already configured). Platform-staff features stay web-only.
3. **Order status transitions are in scope** (user decision): `confirm`, `start_processing`, `mark_shipped`, `mark_delivered`, `cancel` — the existing Ash actions with StatusGuard validations and notification dispatch.
4. **Push is built fully but verified with mocks** (user decision): Pigeon v2 FCM v1 adapter behind a `PushProvider` behaviour; real-device delivery is a follow-up once a Firebase project + service-account JSON exist. Flutter's `firebase_messaging` uses FCM tokens on iOS too, so FCM-only covers both platforms — no direct APNs integration.
5. **Refresh tokens are hand-rolled with rotation.** AshAuthentication has no built-in refresh flow. Access token ~15 min; refresh token ~30 days, stored via the existing token resource, revoked-on-use (rotation) to limit replay.

## Architecture

### Auth endpoints (hand-rolled controller, `:auth_rate_limit` pipeline — 10 req/min)

| Endpoint | Behavior |
|---|---|
| `POST /api/v1/auth/sign_in` | email + password → AshAuthentication password strategy on `Merchant`. Returns `{access_token, refresh_token, expires_in, merchant}`. |
| `POST /api/v1/auth/refresh` | Valid refresh token → new access token + **new** refresh token; the presented refresh token is revoked (rotation). Reuse of a revoked token → 401. |
| `DELETE /api/v1/auth/sign_out` | Revokes the presented refresh token. |

- Access token: JWT signed with the existing `token_signing_secret`, ~15 min lifetime, standard AshAuthentication subject claims.
- Refresh token: JWT with `purpose: "emakola_api_refresh"`, ~30 days, presence stored in `Emakola.Accounts.Token` so revocation works.
- Failure modes: invalid credentials → 401 with opaque message; unconfirmed/archived merchant → 401 (no account enumeration).

### Request pipeline (new `:api_v1` pipeline, stacked on existing `:api` rate limiter)

1. `EmakolaWeb.Plugs.ApiBearerAuth` — extracts `Authorization: Bearer <jwt>`, verifies signature/expiry/purpose, loads the `Merchant`, sets it as Ash actor (`Ash.PlugHelpers.set_actor/2`). Missing/invalid → 401 JSON:API error.
2. `EmakolaWeb.Plugs.ApiTenant` — reads `X-Store-ID` header, validates a `StoreMembership` exists for the actor, sets `Ash.PlugHelpers.set_tenant/2`. Missing header or non-member store → 403. (Convention matches CLAUDE.md: "API: resolve store from X-Store-ID header".)

### Resource endpoints (`ash_json_api`)

`AshJsonApi.Router` mounted at `/api/v1` behind both plugs. Resources gain the `AshJsonApi.Resource` extension; domains gain `AshJsonApi.Domain`.

| Route | Ash action |
|---|---|
| `GET /api/v1/orders` | order list (status filter, keyset pagination, sorted newest-first) |
| `GET /api/v1/orders/:id` | order detail, line items includable via JSON:API `include` |
| `PATCH /api/v1/orders/:id/confirm` (likewise `start_processing`, `mark_shipped`, `mark_delivered`, `cancel`) | existing status-transition update actions |
| `GET /api/v1/stores` | the authenticated merchant's stores (drives store picker; this route works without `X-Store-ID`) |
| `POST /api/v1/device_tokens` | idempotent upsert keyed on token |
| `DELETE /api/v1/device_tokens/:id` | unregister |

Existing Order policies already row-scope merchants via store membership and default-deny nil actors; the API supplies actor + tenant and adds no policy logic of its own. If list pagination requires it, pagination is enabled on the relevant read action (additive, web unaffected).

### DeviceToken resource (`Emakola.Notifications` domain)

| Attribute | Notes |
|---|---|
| `merchant_id` | belongs_to Merchant |
| `store_id` | multitenancy attribute, same `strategy(:attribute)` pattern as Order |
| `platform` | `:android` \| `:ios` (analytics/debugging only) |
| `token` | FCM registration token; unique identity on `[:token]` |
| `last_seen_at` | refreshed on re-registration |

Registration is an upsert: re-registering an existing token updates `merchant_id`/`last_seen_at` (devices change owners on shared phones). Policies: merchants manage only their own tokens within their store.

### Push pipeline

- `Emakola.Notifications.PushProvider` behaviour: `send_push(token, title, body, data) :: {:ok, map()} | {:error, term()}` (final signature may carry a struct; behaviour mirrors existing `SMSProvider` conventions).
- Implementations: `Pigeon` (prod, FCM v1 + Goth), `Log` (dev), Mox mock (test) — config-selected like SMS/WhatsApp providers.
- `Emakola.Notifications.Workers.PushNotificationWorker` (Oban): enqueued by the existing `Dispatcher` on `:order_placed`, alongside the current SMS/WhatsApp jobs. Unique window to dedupe. Looks up the store's merchants' device tokens, sends via the provider, prunes tokens FCM reports as `UNREGISTERED`.
- Pigeon's FCM dispatcher only starts when Firebase credentials are configured (runtime.exs, env-gated) — boots cleanly without them.

### OpenAPI

`ash_json_api`'s OpenAPI support + `open_api_spex`; spec served in dev and generated via `mix openapi.spec.json`. Auth endpoints get hand-written spec entries. The generated spec is the Flutter client contract.

## Error handling

- JSON:API error objects throughout (`errors: [{status, code, detail}]`).
- 401: missing/expired/invalid bearer token; bad credentials; reused refresh token.
- 403: valid token but no membership in the `X-Store-ID` store; policy denials.
- 404: order not found *or not visible under tenant* (no existence leak across stores).
- 422: invalid status transition (StatusGuard) or validation errors.
- Rate limiting: existing `:api` (100/min) and `:auth_rate_limit` (10/min) plugs unchanged.

## Testing (TDD, minimum 90% coverage on new code)

- **Unit:** bearer plug (valid/expired/garbage/wrong-purpose tokens), tenant plug (member/non-member/missing header), refresh rotation logic, DeviceToken upsert.
- **Integration (`@tag :integration`):** full auth flow (sign in → call API → refresh → old refresh token rejected → sign out → token rejected); order list/detail/transition through real HTTP; push worker end-to-end with Mox (order placed → job → provider called with right tokens; UNREGISTERED pruning).
- **Multi-tenant isolation (mandatory):** merchant A with a valid token + forged `X-Store-ID` for store B → 403; order IDs from store B → 404; device tokens scoped per store.
- Never hit real FCM — Pigeon is always behind the behaviour in tests.

## Out of scope (deferred)

- Customer-facing API endpoints (Phase 2 is PWA; customer API only if needed later).
- Web push (`web_push_ex`) — Phase 2.
- Real-device push verification — follow-up checklist item pending Firebase project creation (service-account JSON → `GOOGLE_APPLICATION_CREDENTIALS`-style env config).
- GraphQL, offline sync, websocket order streaming.

## Exit criteria

1. `mix test` green including new integration + isolation suites; `mix format --check-formatted`, `mix credo --strict`, `mix sobelow` clean.
2. Full auth lifecycle demonstrable via `curl` against a dev server.
3. Order list/detail/status-transition working tenant-scoped via the API.
4. Push job observed (Log provider) on order creation in dev.
5. `mix openapi.spec.json` emits a spec covering all endpoints.
