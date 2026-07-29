# Merchant Password Reset — Design

**Date:** 2026-07-29
**Status:** Approved (scope + approach confirmed by Kojo in session)
**Scope:** Merchants only. Store customers (tenant-scoped, store-branded) are a
follow-up; platform staff keep their mix-task recovery path.

## Problem

Merchants have no self-serve password recovery. The login page ships a dead
"Forgot?" link (`href="#"`), and half the feature already exists as orphaned
scaffolding: `Emakola.Accounts.Senders.PasswordResetSender` and
`AuthMailer.password_reset/2` (which links to `/auth/reset-password?token=`)
are live code with no strategy, routes, or UI behind them.

## Approach

AshAuthentication's built-in `resettable` on the existing password strategy
(Approach A). Rejected: ash_authentication_phoenix's `reset_route` (library
components clash with the hand-rolled auth screens + AuthController bridge);
a hand-rolled token flow (reinvents token issuance/expiry with more security
surface).

## Design

### 1. Strategy (`Emakola.Accounts.Merchant`)

Add to the existing `password :password` strategy:

```elixir
resettable do
  sender Emakola.Accounts.Senders.PasswordResetSender
  token_lifetime {24, :hours}
end
```

- Generates `:request_password_reset_with_password` (silently succeeds for
  unknown emails — anti-enumeration is built in) and
  `:password_reset_with_password` (validates token, applies the same password
  rules as registration).
- 24h lifetime: short enough to bound the risk window, long enough for flaky
  mobile email delivery in the target market.
- No schema changes — the `tokens` table already backs magic-link.

### 2. `EmakolaWeb.Auth.ForgotPasswordLive` — `/auth/forgot-password`

- Styled like `LoginLive` (brand panel left, form right, `layout: false`).
- Single email field. Submitting ALWAYS renders the same confirmation copy
  ("If that email has a Makola account, we've sent a reset link") regardless
  of whether the account exists.
- Rate limiting mirrors `LoginLive`'s in-LiveView pattern via
  `Emakola.RateLimit.check_rate/3`:
  - per-IP: 10 requests / minute (`auth_forgot:<ip>`)
  - per-email: 3 requests / 15 minutes (`auth_forgot_email:<email>`) so no
    one can bomb a merchant's inbox.
- Route lives in the existing `/auth` scope → `auth_rate_limit` plug applies
  to page loads too.
- `LoginLive`'s dead "Forgot?" link points here.

### 3. `EmakolaWeb.Auth.ResetPasswordLive` — `/auth/reset-password?token=`

- Reads `token` from params (the URL shape `AuthMailer.password_reset/2`
  already emits).
- Form: new password + confirmation. Errors render through
  `EmakolaWeb.AshErrors.message/1` so `%{min}`-style vars interpolate.
- Invalid/expired token → inline error with a link back to
  `/auth/forgot-password`.
- Success → revoke the merchant's stored tokens (see 4) → redirect to
  `/auth/login` with a success flash. No auto-login: keeps the exchange-token
  dance out of scope and matches common practice.

### 4. Security: sign out everywhere on successful reset

After a successful reset, revoke all stored tokens for the merchant
(`Emakola.Accounts` helper over the `Token` resource). With
`require_token_presence_for_authentication?(true)`, revocation kills every
live session — including any attacker's — and also mobile API refresh
tokens. That is the intended "password changed, sign in again" behavior.

### 5. Error handling

- Unknown email: indistinguishable from success (UI + timing are the same
  render path).
- Rate-limited: explicit "try again in a minute" flash (matches LoginLive).
- Sender failures: `PasswordResetSender` already rescues/logs; the UI still
  shows the neutral confirmation (an email outage must not become an
  enumeration oracle).

## Testing

- **Resource level** (`test/emakola/accounts/password_reset_test.exs`):
  request → email delivered (Swoosh test assertions, link contains
  `/auth/reset-password?token=`); unknown email → no email, same return
  shape; valid reset → old password dead, new password signs in; garbage or
  expired token → error; post-reset → previously issued tokens revoked.
- **LiveView level**: both screens — render, submit paths, rate-limit
  denial, invalid-token state, `%{min}` interpolation on short passwords.
- **E2E (Playwright)**: full journey against the dev server — request reset
  for a seeded merchant, pull the real link out of `/dev/mailbox`, set a new
  password, sign in with it. Uses `efua@tinystitches.com` (not kwame, whose
  credentials back the suite's shared storageState) and always resets to the
  same deterministic password so reruns stay stable.

## Out of scope

- Customer (storefront) password reset — needs tenant context + store
  branding; separate spec.
- Auto-login after reset.
- Email template redesign (existing `AuthMailer.password_reset/2` copy ships
  as-is).
