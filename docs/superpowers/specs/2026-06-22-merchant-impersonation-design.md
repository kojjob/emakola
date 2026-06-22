# Merchant Impersonation — Design

## Context

Platform staff need to securely "log in as" a merchant — audited and time-boxed — to reproduce issues and support them. Third platform-admin backlog item after store lifecycle (#190) and KYC (#191); reuses the audit + permission infrastructure.

The crux is **session bridging**: turning a platform-staff browser session into a merchant session while remembering the real staff actor, with a clean exit. No existing "act-as" code exists.

**Decisions (with user):** full read-write access while impersonating (true read-only is impractical — it'd mean gating writes across 40+ admin LiveViews); one-click start (gated `:manage_merchants`, no re-auth — the platform login already required password+TOTP); 30-minute time-box; reuse `:manage_merchants` permission.

Branch: `feature/merchant-impersonation`. TDD throughout.

## How auth resolves today (from exploration)

- Merchant session = `:user_token` (signed AshAuthentication subject via `AuthTokens.sign_subject`). `AssignDefaults` verifies it → `current_merchant` via `subject_to_user`.
- Platform session = `:platform_session_token` (signed DB `UserSession` id). `AssignDefaults` checks platform **first**; if valid → `current_user`, returns early.
- `AssignDefaults` (`lib/emakola_web/hooks/assign_defaults.ex`) is the resolution hub. `RequireAuth` (merchant `:app` session) requires `current_merchant`.

## Session model (token swap)

Start/stop are **controller** actions (cookies need a plug, not LiveView). New `EmakolaWeb.ImpersonateSessionController`:

- **`POST /platform/impersonate/:merchant_id` → `:start`** (`:browser` + `:auth_rate_limit`):
  1. Verify real staff from `:platform_session_token` (`AuthTokens.verify_platform_session` → `Sessions.verify_session_id`); re-check `PlatformPermissions.allowed?(user, :manage_merchants)`. Fail → redirect `/platform`.
  2. Load target merchant (`Accounts.get_merchant`). Missing → redirect `/platform`.
  3. Session writes: stash `return_session_id` = staff `UserSession.id`; **delete** `:platform_session_token`; set `:user_token` = `sign_subject(user_to_subject(merchant))`; set `:impersonation = %{"staff_user_id" => id, "merchant_id" => id, "expires_at" => unix+1800, "return_session_id" => id}`.
  4. `PlatformAudit.log(:impersonation_started, staff, %{merchant_id, merchant_email, merchant_name}, ip)`. Redirect `/dashboard`.
- **`GET /platform/impersonate/exit` → `:exit`** (`:browser`): read `:impersonation`; re-sign `:platform_session_token` from `return_session_id` (the `UserSession` was never revoked, so the staff session restores cleanly); delete `:user_token` + `:impersonation`; `PlatformAudit.log(:impersonation_ended, staff_user_id, %{merchant_id}, ip)`. Redirect `/platform`. Idempotent (no `:impersonation` → just redirect).

The staff's `UserSession` row is **not revoked** during impersonation — exit re-signs its id. Exit is GET so the banner link and the expiry-redirect can both reach it.

## AssignDefaults change (merchant path only; platform path untouched)

In `resolve_merchant_token`/`resolve_merchant` (the `:user_token` path), when `session["impersonation"]` is present:
- **Expired** (`expires_at` < now) → `{:halt, redirect(to: "/platform/impersonate/exit")}` (graceful auto-exit + cleanup).
- **Active** → load the staff user (`get_user_by_id(staff_user_id)`) and assign `impersonator: staff_user` alongside the impersonated `current_merchant`/`current_store`.

A normal merchant login has no `:impersonation` → `impersonator: nil`, behaviour unchanged. Assign `impersonator: nil` in the platform + unauthenticated paths too so the layout assign always exists.

## Banner

A persistent amber bar at the top of `lib/emakola_web/components/layouts/app.html.heex`, shown when `@impersonator` is set: "You (<staff email>) are viewing <merchant name>'s account — **Exit**" linking to `/platform/impersonate/exit`. Sits above the topbar (z-index above it).

## Entry point

An "Impersonate" button in the existing Merchants drawer (`lib/emakola_web/live/platform/merchant_live/index.ex`), a CSRF-protected `<form method="post">` to `/platform/impersonate/:merchant_id`, shown only with `:manage_merchants` (drawer is already gated, but guard the button too).

## Audit

Add `:impersonation_started` / `:impersonation_ended` to `PlatformAuditLog` `one_of` (`platform_audit_log.ex`); add to `audit_log_components.ex` severity (`started` → amber, `ended` → green).

## Files

- `lib/emakola_web/controllers/impersonate_session_controller.ex` (new) + router (`/platform` scopes)
- `lib/emakola_web/hooks/assign_defaults.ex` (impersonator + expiry)
- `lib/emakola_web/components/layouts/app.html.heex` (banner)
- `lib/emakola_web/live/platform/merchant_live/index.ex` (Impersonate button in drawer)
- `lib/emakola/accounts/resources/platform_audit_log.ex` (+2 atoms) + `…/platform/audit_log_components.ex` (colors)
- (reuse `AuthTokens`, `Sessions`, `PlatformAudit`, `PlatformPermissions`, `Accounts.get_merchant`/`get_user_by_id`)

## Build sequence (tests → impl → green)

1. Audit atoms + component colors.
2. `AssignDefaults` impersonation resolution (impersonator assign + expiry auto-exit) → hook tests.
3. `ImpersonateSessionController` start/exit + routes → controller tests (session swap, audit, permission gate, missing merchant, idempotent exit).
4. Banner in app layout + Impersonate button in Merchants drawer → render/integration tests.
5. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`.

## Verification (end-to-end)

Automated: controller tests (start sets `:user_token`+`:impersonation`, deletes `:platform_session_token`, audits, requires staff+permission, 404s missing merchant; exit restores `:platform_session_token`, clears keys, audits); `AssignDefaults` test (impersonation → `current_merchant` = target + `impersonator` = staff; expired → redirect to exit); banner renders with Exit when impersonating; merchant LiveView reachable under an impersonated session. Suite green + format + credo.

Manual: as platform staff, open `/platform/merchants`, a merchant drawer → Impersonate → land on `/dashboard` as that merchant with the amber banner → Exit → back to `/platform` as staff; both events in `/platform/audit-log`.

## Security notes

- Start verifies staff + permission server-side (never trusts the client); fails closed.
- Full access is intentional; the banner + start/end audit + 30-min box are the safeguards.
- Impersonated session respects all merchant gates (`RequireActiveStore` etc.) — a suspended store shows the merchant's own lockout.
- `:impersonation` is only ever set by the start controller (staff-gated); a real merchant can never have it.
