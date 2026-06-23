# Security Event Log + Abuse Monitor — Design

## Context

Second of the three remaining platform-admin features. Fraud/abuse data isn't currently
persisted (rate-limiter only `Logger.warning`s 429s; the merchant `Emakola.Audit` log is
dormant/empty; only platform-staff auth lands in `platform_audit_log`). **Decision (with
user): build the persistence layer** — a `SecurityEvent` log fed by instrumentation —
then a monitor. **Events captured v1: rate-limit exceedances + failed sign-ins.**

Built in the **Makola Admin design language** (see `[[emakola-admin-ui-standard]]`):
stat tiles, `rounded-2xl` cards, gradient/severity data-viz, rich empty states.

Branch: `feature/security-event-monitor`. TDD throughout.

## Data — `Emakola.Security` domain + `SecurityEvent`

`SecurityEvent` (platform-owned, not tenant-scoped), table `security_events`:
- `event_type` :atom `one_of [:rate_limit_exceeded, :auth_failed]` (extensible)
- `subject_type` :atom `one_of [:merchant, :customer, :platform, :anonymous]`, default `:anonymous`
- `identifier` :string nullable — attempted email/phone, or the rate-limit key
- `ip` :string nullable — source IP
- `path` :string nullable — request path
- `metadata` :map default `%{}`
- `inserted_at` (create timestamp). Indexes: `inserted_at`, `ip`, `event_type`.
- Policies: `bypass action_type(:read) do authorize_unless(actor_present()) end`; `policy action_type([:create]) do forbid_if always() end` (writes are internal, `authorize?: false`).
- Actions: `defaults [:read]`; `create :record` (accept all fields); `read :recent` (sort `inserted_at` desc, default limit 50); `read :since` (arg `as_of`, filter `inserted_at >= ^as_of`).

`Emakola.Security` module:
- **`record/1`** — fire-and-forget, never raises (rescue → Logger). Mirrors `PlatformAudit.log`. Takes `%{event_type:, subject_type?, identifier?, ip?, path?, metadata?}`, inserts via `:record` with `authorize?: false`.
- **`overview/1`** (`as_of` = now) — loads last-24h events once, computes:
  `%{total: n, by_type: %{rate_limit_exceeded: n, auth_failed: n}, top_ips: [%{ip, count, flagged}], top_identifiers: [%{identifier, count}], recent: [event], anomaly_count: n}`.
  Anomaly = ip/identifier with `count >= @anomaly_threshold` (10) in the window.
- Code interfaces: `record_security_event`, `recent_security_events`, `security_events_since`.

## Instrumentation (3 points, all via `Security.record/1`)

1. **`RateLimiter` plug** (`plugs/rate_limiter.ex`) `:deny` branch → `record(%{event_type: :rate_limit_exceeded, ip: client_ip(conn), path: conn.request_path, identifier: key, metadata: %{"limit" => limit}})`.
2. **Merchant `LoginLive`** (`live/auth/login_live.ex`) `{:error, _}` branch → `record(%{event_type: :auth_failed, subject_type: :merchant, identifier: params["email"], ip: connect_ip})` (IP captured at mount via `get_connect_info(socket, :peer_data)`, nil-safe).
3. **Customer phone-OTP verify failure** (`live/storefront/customer_whats_app_live.ex`) → `record(%{event_type: :auth_failed, subject_type: :customer, identifier: phone})`.

`record/1` never raising means instrumentation can never break a request/login. More flows (merchant phone-OTP, OAuth) are trivial follow-ons.

## Monitor — `/platform/security-events` (`SecurityEventsLive`)

Gated by existing **`:view_audit_log`** permission. Distinct from `/platform/security`
(self-service 2FA). Loading-shell (Iron Law #1); `Security.overview/1` on connected mount.

Elevated UI:
- **Hero stat tiles** (4): Events (24h) · Rate-limit hits · Failed sign-ins · Flagged sources — each a `rounded-2xl` tile with icon chip, large numeral, severity accent.
- **Top source IPs (24h)** — leaderboard: IP, count, a gradient severity bar; flagged rows tinted red with a "flagged" pill.
- **Recent events** — clean table: time, severity-pill type, subject, identifier, IP, path.
- **Empty state** — shield icon + "No security events in the last 24h — all quiet" copy.
- Nav link "Security events" (icon `shield`) in the platform sidebar after "Audit log".

## Build sequence (tests → impl → green)

1. `SecurityEvent` resource + `Security.record/1` + `overview/1` + interfaces + migration → resource/domain tests (record persists & never raises on junk; overview counts by type, top-IP ranking, anomaly threshold, recent ordering).
2. Instrument rate-limiter + merchant login + customer OTP → tests (plug deny records an event; login `{:error}` records `:auth_failed`).
3. `SecurityEventsLive` + route + nav (elevated UI) → LiveView tests (renders tiles + recent + flagged; permission gating; empty state).
4. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, `mix test --warnings-as-errors` on new test files. PR + CI.

## Out of scope (v1)

Success/baseline logging; real-time alerting/notifications; auto-blocking; retention/prune
job; merchant/customer-facing views; order/payment fraud scoring.
