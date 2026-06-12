# Platform Admin Auth — Design Spec

**Date:** 2026-06-11
**Status:** Approved for implementation
**Scope:** Production-grade platform admin authentication: invite-only registration for platform owners and team members, signed sessions, TOTP 2FA, fine-grained permissions, audit log, active session management.

---

## 1. Problem

The `/platform` admin area exists (Dashboard, Stores) but is unreachable and insecure:

1. **Critical security hole** — `GET /auth/session?token=...` (`lib/emakola_web/controllers/auth_session_controller.ex:9`) stores a raw, **unsigned** AshAuthentication subject string (`user?id=<uuid>`) in the session verbatim. `lib/emakola_web/plugs/auth.ex` and `lib/emakola_web/hooks/assign_defaults.ex` trust it via `AshAuthentication.subject_to_user/2`. Anyone who knows or guesses a user UUID becomes that user with one URL. The same hole exists for customers (`lib/emakola_web/controllers/storefront/customer_session_controller.ex:12`).
2. **Platform admin unreachable** — merchants sign in as `Merchant`; the `is_platform_admin` gate checks `current_user` (a `User`), which merchant sessions never populate.
3. **No team story** — no way to register platform owners or invite staff.

## 2. Decisions (user-approved)

| Decision | Choice |
|---|---|
| Registration model | Bootstrap first owner via mix task; everyone else invite-only via emailed `PlatformInvite`. No public registration page. |
| Identity | `User` resource repurposed as platform-staff identity. Merchants stay on `Merchant`. |
| Permissions | Fine-grained: `platform_permissions {:array, :atom}` on User + `is_owner` boolean (owners bypass checks and manage the team). Catalog: `manage_stores`, `manage_merchants`, `manage_team`, `view_audit_log`, `manage_billing`, `manage_settings`. |
| Auth features | TOTP 2FA (enforced for all staff), auth audit log, active session management. No magic link for staff. No backup codes — recovery via owner reset (team page) or `mix emakola.reset_platform_totp` for a locked-out sole owner. |
| Untouched | Existing Organisation/Membership resources stay as-is. |

## 3. Architecture

### Token signing — `EmakolaWeb.AuthTokens` (wraps `Phoenix.Token`)
- `sign_subject/verify_subject` — salt `"auth_subject_v1"`, max_age 30 days. Merchant + customer subjects (minimal fix; no DB sessions for them in this build). Single salt is safe: `subject_to_user` enforces the resource prefix.
- `sign_platform_session/verify_platform_session` — salt `"platform_session_v1"`, max_age 14 days. Payload: `UserSession` UUID.
- `sign_login_exchange/verify_login_exchange` — salt `"platform_login_exchange_v1"`, max_age 30 seconds. Payload: user UUID. Bridges LiveView → controller (LiveView cannot write the session cookie).

### Sessions — `Emakola.Accounts.UserSession` + `Emakola.Accounts.Sessions` service
DB-backed session rows (`user_id`, `ip`, `user_agent`, `last_seen_at`, `revoked_at`). Cookie holds the Phoenix.Token-signed session UUID under `:platform_session_token`. One mechanism gives both unforgeable sessions and the list/revoke UI. Service: `create/3`, `verify_session_id/1` (rejects revoked, idle >24h, deactivated user), `touch/1` (write only if `last_seen_at` >5 min stale), `revoke/1`, `revoke_all_for_user/1`, `list_active_for_user/1`.

Session cookie keys: `:platform_session_token` (staff), `:user_token` (merchant-only signed subject), `:customer_token` (signed subject).

### Login flow
`/platform/login` LiveView, steps `:credentials` → `:totp_setup` (first login: QR + manual secret + confirm) → `:totp` → redirect to `GET /platform/session?t=<30s exchange token>` → `PlatformSessionController` re-verifies active staff, creates the session row with real conn ip/UA, signs id, `put_session` + `configure_session(renew: true)`, audits, redirects to `/platform`. Logout: `DELETE /platform/session` revokes the row (no `configure_session(drop: true)` — preserves a coexisting merchant session).

Credential verification keeps AshAuthentication's password strategy (`Strategy.action(strategy, :sign_in, ...)` — constant-time); the JWT it mints is ignored.

### TOTP — `Emakola.Accounts.TOTP` (NimbleTOTP + eqrcode)
`generate_secret/0`, `otpauth_uri/2` (issuer "Emakola Platform"), `qr_svg/1`, `valid_code?/3` accepting current + previous 30s window with `since: totp_last_used_at` to block code reuse. Secret stored as sensitive binary on User. Setup enforced at first login.

### Invites — `Emakola.Accounts.PlatformInvite`
`email`, `permissions` (catalog one_of), `token_hash` (sha256 of 32 random url-base64 bytes; raw token only in changeset context for the mailer), `invited_by_id`, `expires_at` (7d), `accepted_at`, `revoked_at`. Accept page at `/platform/invite/accept/:token` → set name + password → redirected to `/platform/login` where TOTP setup is forced. Invites carry permissions only, never `is_owner` — owner promotion is an explicit post-acceptance action by an existing owner.

### Audit log — `Emakola.Accounts.PlatformAuditLog`
Append-only (no update/destroy actions): `actor_id` (nullable), `action` one_of `[:sign_in_succeeded, :sign_in_failed, :totp_failed, :totp_enabled, :invite_created, :invite_accepted, :invite_revoked, :permissions_changed, :owner_changed, :session_revoked, :sessions_force_revoked, :staff_deactivated, :staff_reactivated, :sign_out]`, `metadata :map`, `ip`, `inserted_at`. Ash mutations audit via in-transaction `after_action` changes (cannot be forgotten); non-changeset events call `Emakola.Accounts.PlatformAudit.log/4` explicitly.

### Permission gating
`Emakola.Accounts.PlatformPermissions` (`all/0`, `allowed?/2` with owner bypass, `valid?/1`, `cast_list/1` via `Emakola.SafeAtom.to_atom_in/3`). LiveView hook `EmakolaWeb.Hooks.RequirePermission` per page; permissions re-checked in every `handle_event`; `RequirePlatformStaff` replaces RequireAuth + RequirePlatformAdmin in the `:platform` live_session. Last-owner protection: the last active owner cannot be demoted or deactivated.

### Pages
- `/platform/login` — two-step login (new `:platform_auth` live_session, rate-limited)
- `/platform/invite/accept/:token` — invite acceptance
- `/platform/team` — staff list, invite form with permission checkboxes, edit permissions, deactivate/reactivate, force-logout, reset-2FA (gated `:manage_team`)
- `/platform/security` — own 2FA status + active sessions with revoke (any staff)
- `/platform/audit-log` — streamed, keyset-paginated log (gated `:view_audit_log`)
- Existing `/platform/stores` gated by `:manage_stores`; Dashboard stays any-staff.

## 4. Implementation phases (one conventional commit each, TDD)

1. `fix(auth): sign session subjects with Phoenix.Token` — closes the hole for user, merchant, and customer flows immediately. Updates the 4 raw-subject call sites (`login_live.ex:234`, `register_live.ex:253`, `customer_login_live.ex:30`, `customer_register_live.ex:48`) and test helpers.
2. `feat(accounts): platform staff fields and permission catalog` — User gains `is_owner`, `platform_permissions`, `totp_secret`, `totp_last_used_at`, `deactivated_at`; drops `is_platform_admin` (migration copies flag to `is_owner` first). `mix emakola.bootstrap_platform_owner <email>`.
3. `feat(accounts): platform audit log`
4. `feat(auth): DB-backed platform sessions` — UserSession resource, Sessions service, PlatformSessionController, plug/hook resolution, `RequirePlatformStaff`, factories/helpers.
5. `feat(accounts): TOTP support` — deps, wrapper module, User actions, reset mix task.
6. `feat(platform): two-step login with enforced TOTP`
7. `feat(platform): invite-only staff registration` — resource, mailer, accept LiveView, edge cases (expired/accepted/revoked/email-collision).
8. `feat(platform): team management page`
9. `feat(platform): security page (own 2FA + sessions)`
10. `feat(platform): audit log page`
11. `feat(platform): gate existing pages and retire legacy user login` — merchant-only `/auth/login`, remove `user?` subject handling, fix platform layout logout to DELETE.
12. `chore(auth): run token expunger and cleanup` — add `{AshAuthentication.Supervisor, otp_app: :emakola}` to `application.ex` (fixes pre-existing unbounded `tokens` table growth).

Each phase ends with `mix format && mix credo --strict && mix test`.

## 5. Risks / accepted trade-offs

1. Phase 1 deploy logs out all merchants/customers once (communicate it).
2. Legacy non-staff User logins to `/dashboard` end at Phase 11 — confirm prod has no such users first (Phases 1–10 are safe regardless).
3. The 30s login-exchange token is not single-use; replay within 30s creates a duplicate, visible session for the same user. Accepted.
4. TOTP secret stored unencrypted (sensitive binary) — DB compromise already exposes password hashes; flagged for a future hardening pass.
5. Timing knobs (14d absolute session, 24h idle, 5-min touch granularity, 7d invite expiry, 30s exchange) live in module attributes.

## 6. Verification

1. Per phase: `mix format --check-formatted && mix credo --strict && mix test`.
2. Security regression: `GET /auth/session?token=user%3Fid%3D<uuid>` (raw subject) must NOT establish a session; same for the customer endpoint.
3. End-to-end: bootstrap owner → `/platform/login` → password → forced TOTP setup → `/platform` → invite staff with only `:manage_stores` → accept via dev mailbox link → staff sees Stores, is bounced from Team/Audit → owner force-logs-out staff → staff redirected to login → audit log shows the whole story.
4. Merchant/customer regression: existing storefront and merchant admin login/logout still work (now signed).

## 7. Versions / facts verified during design

- `ash_authentication 4.13.7` (no TOTP strategy; password strategy retained for credential checks), `ash 3.27.8`, `phoenix 1.8.7`, `hammer 7.4.0`. `nimble_totp`, `eqrcode` are new deps.
- `AshAuthentication.Supervisor` missing from supervision tree → tokens never expunged (pre-existing leak, fixed in phase 12).
- `is_platform_admin` referenced in only 3 files.
