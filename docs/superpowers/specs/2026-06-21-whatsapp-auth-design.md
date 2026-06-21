# WhatsApp Authentication (phone + OTP) + Auth-Page UI/UX — Design

## Context

WhatsApp is how West Africa transacts, and the merchant auth pages already carry
a disabled **"Continue with WhatsApp (Coming Soon)"** button. This delivers
real **phone + one-time-code authentication over WhatsApp** (with an SMS
fallback) for **both merchants and customers**, and tightens the auth pages so
WhatsApp, social, and email sign-in read consistently.

WhatsApp is **not** an OAuth provider — "WhatsApp auth" = enter phone → a 6-digit
code is delivered over WhatsApp → verify → signed in. This is a **custom flow**
(ash_authentication has no phone-OTP strategy; its `magic_link` is link-based,
not code-based).

### Decisions (from brainstorming)
- **Scope:** merchants **and** customers.
- **UI/UX scope:** the **auth pages only** (integrate WhatsApp + polish; no broader redesign).
- **Delivery:** **WhatsApp, with SMS fallback** (works even before the Meta template clears).
- **New users:** **find-or-create, collecting email once** — after the code verifies, a new user gives an email (+ optional name) and the account is created. Email stays required (receipts, password reset, customer uniqueness, OAuth-link-by-email all keep working); phone becomes an additional login method. No schema-relaxation risk.

### What already exists (reuse)
- `Emakola.Notifications.Channels.WhatsApp.send_message/4` (Business API, template-based) + `WhatsAppProvider` behaviour + `WhatsAppProviderMock`.
- The SMS channel + `SMSProvider` behaviour + mock.
- `Emakola.RateLimit.check_rate/3` (Hammer) for throttling.
- `phone` attribute on `Merchant` and `Customer` (nullable today).
- Session minting: `EmakolaWeb.AuthTokens.sign_subject/1` → `:user_token` (merchant) / `:customer_token` (customer) via the existing session controllers.
- A reusable numeric `code_input` pattern in `lib/emakola_web/live/platform/login_components.ex` (one-time-code autofill, letter-spaced).
- `bg-whatsapp` (#25D366) Tailwind token; mature design tokens.

### Gaps to build
- A Meta **authentication-category** WhatsApp template (e.g. `auth_code`, one `{{1}}` param) — 1–3 day approval (SMS fallback covers the gap).
- OTP generate/store/verify infra (numeric phone OTP — distinct from the platform's authenticator TOTP).
- Phone-based lookup + uniqueness (phone is currently a plain, non-unique attribute).

---

## Architecture

### 1. `Emakola.Accounts.PhoneOtp` (new Ash resource, global)
Backing store for issued codes. Fields:
- `id` (uuid)
- `phone` (string, normalized E.164, e.g. `+233501234567`)
- `code_hash` (string, **hashed** — never store the plaintext code; Bcrypt, already available)
- `purpose` (atom: `:merchant` | `:customer`)
- `store_id` (uuid, nullable — set for `:customer`)
- `expires_at` (utc_datetime_usec, ~10 min)
- `attempts` (integer, default 0)
- `consumed_at` (utc_datetime_usec, nullable)
- timestamps

Actions: `create` (issue), `verify` (consume + check), a read by phone+purpose. A
small daily Oban prune worker deletes expired/consumed rows (housekeeping).

### 2. `Emakola.Accounts.PhoneAuth` (new service module)
The coordination layer (returns `{:ok, _}` / `{:error, reason}`):
- `request_code(phone, purpose, opts)` — normalize phone; rate-limit
  (`"phone_otp:send:#{phone}"`); generate a 6-digit code; store a hashed `PhoneOtp`;
  **send via WhatsApp, fall back to SMS** on failure/unconfigured. Returns
  `{:error, :rate_limited | :delivery_failed}` as needed.
- `verify_code(phone, code, purpose, opts)` — fetch the latest live OTP; enforce
  expiry + attempt cap (`attempts < 5`) + a verify rate-limit; compare the hash;
  consume on success. Returns `{:error, :invalid | :expired | :too_many_attempts}`.
- Delivery uses the existing `WhatsAppProvider` (template `auth_code`) and
  `SMSProvider` (plain text) behind config, so tests use the Mox mocks.

### 3. Account resolution (find-or-create by **verified** phone)
The phone is OTP-verified, so a verified-phone lookup is as trustworthy as a
verified email.
- **Merchant:** look up by unique phone → sign in if found; else collect email
  (+ name) → create via a new passwordless `register_with_phone` action
  (`hashed_password` is already nullable for magic-link merchants; sets
  `confirmed_at`).
- **Customer:** look up by `[store_id, phone]` within the tenant → sign in if
  found; else collect email (+ name) → create via a phone-create action
  (store_id from the route tenant; `hashed_password` nullable).
- **Uniqueness:** add `Merchant` identity `unique_phone [:phone]` and `Customer`
  identity `unique_store_phone [:store_id, :phone]` (+ migrations). Postgres
  allows multiple NULLs, so existing email-only rows are unaffected (DB is
  effectively empty anyway).

### 4. Web flow (LiveView, per audience)
Two small LiveViews, each a 2–3 step state machine (`:phone → :code → [:email] → done`):
- **Merchant:** `EmakolaWeb.Auth.WhatsAppLive` at `/auth/whatsapp`. On success →
  `AuthTokens.sign_subject` → redirect `/auth/session?token=…` (existing controller) → `/dashboard`.
- **Customer:** `EmakolaWeb.Storefront.CustomerWhatsAppLive` at
  `/s/:store_slug/whatsapp` (store-scoped — **tenant known from the route**, so no
  OAuth-style callback gymnastics). On success → `/s/:slug/auth/customer-session?token=…` → `/s/:slug/account`.

The "Continue with WhatsApp" buttons navigate to these (no longer disabled),
shown only when phone-auth is configured (ship-dark via an
`EmakolaWeb.PhoneAuth.enabled?` config check).

### 5. UI/UX (auth pages only)
- **`EmakolaWeb.AuthComponents.otp_code_input/1`** — extracted from the platform
  `code_input` into a shared component (numeric, `autocomplete="one-time-code"`,
  letter-spaced), reused by merchant + customer + (future) platform.
- **Phone input** — Ghana **+233** default (small country select: +233/+234),
  `inputmode="tel"`, helper text "no leading 0".
- **Resend** — a cooldown ("Resend in Ns") backed by the send rate-limit.
- **Consistency pass** — same button order everywhere: **WhatsApp · social
  (`oauth_buttons`) · email form**, with one shared divider treatment; align
  merchant (dark `#0c1526`) and customer (store-themed `cta-dark`) so the three
  sign-in methods read as one coherent set. This is the entire "UI/UX update".

---

## Data flow (happy path)
1. User taps **Continue with WhatsApp** → WhatsAppLive (`:phone`).
2. Enters phone → `PhoneAuth.request_code/3` → hashed `PhoneOtp` stored + code sent (WhatsApp → SMS fallback) → step `:code`.
3. Enters code → `PhoneAuth.verify_code/4` → consumed.
4. Resolve account: found → sign in; new → step `:email` → create → sign in.
5. Sign-in mints the existing session token → existing session controller → dashboard / store account.

## Error handling
- Invalid / expired / too-many-attempts → inline message, stay on `:code`; offer resend (after cooldown).
- Send fails on WhatsApp → automatic SMS fallback; both fail → "Couldn't send a code, try again" (never leaks which channel).
- Rate-limited (send or verify) → friendly "try again in a minute".
- Phone normalization failure (bad format) → inline validation before sending.

## Security
- Codes **hashed** at rest, single-use (`consumed_at`), ~10-min expiry, ≤5 attempts.
- Two rate-limit keys (send vs verify) per phone via `Emakola.RateLimit`.
- Find-or-create only on an **OTP-verified** phone (proves control) — same trust model as verified email.
- Phone uniqueness identities prevent ambiguous lookups.
- Customer flow stays tenant-scoped (OTP + lookup + create carry `store_id`); no cross-store leakage.
- No plaintext code in logs.
- Every OTP `handle_event` validates its action; user inputs (phone, code) are handled as **strings** — never `String.to_atom`'d (`purpose` is a fixed atom set by the route, not user input).

## Testing
- `PhoneOtp` / `PhoneAuth`: issue, verify (valid/invalid/expired/too-many-attempts/consumed), send rate-limit, **WhatsApp→SMS fallback** (Mox).
- Account resolution: existing-phone sign-in; new-phone → email step → create; merchant (global) + customer (store-scoped, cross-store isolation).
- Session minting: merchant `:user_token` → `/dashboard`; customer `:customer_token` → `/s/:slug/account`.
- LiveView: phone→code→[email]→signed-in; resend cooldown; bad code.
- Ship-dark: WhatsApp button hidden when phone-auth unconfigured.
- `mix test` · `mix format --check-formatted` · `mix credo --strict` clean.

## Dependencies / activation
- **Meta authentication-category template** (`auth_code`) — submit + await approval (1–3 days). **SMS fallback carries OTP until then**, so this ships + deploys before the template clears.
- Reuses existing `WHATSAPP_*` / `SMS_*` secrets.

## Out of scope
- Password reset over phone; phone as the *sole* identity (email still collected once).
- Country codes beyond +233/+234 (extensible later).
- Any non-auth-page UI work (broader redesign).
- Platform-staff phone auth (stays password + TOTP).

## Sequencing note
The customer auth pages are also touched by **PR #179** (customer OAuth, pending
merge). To avoid another stacked-PR cascade, implement this **after #179 lands on
main**, branching fresh from main so the auth pages are settled.

## Verification (end-to-end)
- Merchant: `/auth/whatsapp` → phone → code (SMS in dev/mock) → `/dashboard`; new phone prompts email then creates.
- Customer: `/s/:slug/whatsapp` → same → `/s/:slug/account`, scoped to the store.
- Button hidden until configured; WhatsApp send falls back to SMS when WhatsApp errors.
