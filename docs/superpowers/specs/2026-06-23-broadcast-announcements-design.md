# Platform Broadcast Announcements — Design

## Context

The platform owner needs a way to message merchants — maintenance notices, policy
changes, feature launches (e.g. the new payout page), demand-validation outreach.
Today there is no platform→merchant broadcast channel. This is the next
platform-admin feature after the prioritized backlog (lifecycle / KYC /
impersonation / moderation) shipped and payout onboarding (#197) landed.

**Decisions made with the user (brainstorming):**
1. **Channels:** all four — in-app banner + email + SMS + WhatsApp.
2. **Targeting:** all stores, or by lifecycle-status segment (`:all` vs `:active`,
   where active skips archived/blocked/suspended — also avoids paying to SMS dead stores).
3. **Lifecycle:** schedule for later (or now) + optional expiry.
4. **WhatsApp constraint (surfaced):** the Cloud API only sends *pre-approved
   templates* (`channels/whatsapp.ex` rejects unknown templates). So WhatsApp
   carries a **templated nudge** ("New announcement from Makola: {title} — sign in
   to read") via a new `announcement` template, **shipped dark** until Meta approves
   it. The full body rides banner + email + SMS (all free-text).
5. **Permission:** new `:manage_announcements` platform permission (least-privilege).
6. **Delivery architecture:** two-worker fan-out (recommended approach A).

Branch: `feature/broadcast-announcements`. TDD throughout (tests first; ≥90% on new code).

## Architecture — two-worker fan-out (Approach A)

Mirrors the existing per-entity worker pattern (`StoreStatusNotificationWorker`):

- **`AnnouncementPublishWorker`** — enqueued on create with `scheduled_at: publish_at`.
  At publish time: if the announcement is still `:scheduled`, flip it to `:published`,
  resolve target stores (all, or filtered by `audience`), and enqueue one
  `AnnouncementDeliveryWorker` **per store** for the external channels. Idempotent:
  already-published or `:canceled` → no-op.
- **`AnnouncementDeliveryWorker`** — per store. Loads announcement + store; for each
  external channel in `channels` sends to `contact_email` / `contact_phone` /
  `whatsapp_number`, skipping a channel the store hasn't filled in. Mirrors
  `StoreStatusNotificationWorker`'s `maybe_send_*` helpers (per-store retry isolation,
  no double-sends — important with paid SMS). The in-app `banner` channel needs **no**
  delivery job — it is query-driven.

Rejected — **Approach B (single inline worker):** one job loops all stores and sends
inline; a mid-list failure retries the whole job and re-SMSes earlier stores. Worse
with paid channels.

## Data model (`Emakola.Notifications` domain)

`lib/emakola/notifications/notifications.ex` registers two new resources.

### `Emakola.Notifications.Announcement` (platform-owned, not tenant-scoped)
- `title :string` — required.
- `body :string` — required; the full message (banner / email / SMS).
- `severity :atom` — `one_of [:info, :warning, :critical]`, default `:info` (drives banner color).
- `channels {:array, :atom}` — subset of `[:banner, :email, :sms, :whatsapp]`, at least one.
- `audience :atom` — `one_of [:all, :active]`, default `:all`. `:active` targets only
  live stores (`active == true and status == :active`).
- `publish_at :utc_datetime_usec` — required; now or future.
- `expires_at :utc_datetime_usec` — nullable; banner hides after this.
- `status :atom` — `one_of [:scheduled, :published, :canceled]`, default `:scheduled`.
- timestamps.

**"Active for banner" is derived, not a stored status** — no expiry cron:
`status == :published and publish_at <= now and (is_nil(expires_at) or expires_at > now)`.
A read `:active_for_store` returns these. Actions: `:create` (sets `:scheduled`,
enqueues the publish worker — but enqueue from the LiveView after create, not in an
after-action, to keep the action pure), `:publish` (worker), `:cancel`,
`:list_for_admin`. Platform-only writes: policy `forbid_if always()` + call with
`authorize?: false` from gated LiveView/worker (the established platform-action pattern).

### `Emakola.Notifications.AnnouncementDismissal`
- `announcement_id :uuid`, `merchant_id :uuid`.
- `identity unique_dismissal [:announcement_id, :merchant_id]`.
- timestamps.
- Per-merchant banner dismissal. Actions: `:dismiss` (upsert on the identity),
  `:list_for_merchant`.

## Merchant in-app banner

New hook **`EmakolaWeb.Hooks.MerchantAnnouncements`** in the `:app` live_session
(after `AssignDefaults`, keeping that hook focused):
- Assigns the current store's active announcements minus the ones this merchant
  dismissed → `@announcements`.
- `attach_hook(socket, :announcements, :handle_event, …)` handles
  `"dismiss_announcement"` globally across all merchant LiveViews → `:dismiss` upsert,
  then removes that announcement from the assign.

Banner component in `app.html.heex` mirrors the impersonation banner (`:if`-rendered,
severity-colored, dismiss button posting `dismiss_announcement` with the id). Only
banner-channel announcements (`:banner in channels`) show here.

## Platform UI

`/platform/announcements` → **`EmakolaWeb.Platform.AnnouncementLive.Index`**:
- List: title, severity, audience, channel chips, schedule/expiry, derived state
  (Scheduled / Live / Expired / Canceled), with a Cancel action.
- "New announcement" form: title, body, severity, channel checkboxes, audience,
  `publish_at`, `expires_at`. On submit → create + enqueue publish worker + audit.
- Iron Law #1 loading shell (no DB on disconnected mount).
- `on_mount {RequirePermission, :manage_announcements}`; every mutating `handle_event`
  re-checks via the `authorized/2` + `reload_current_user/1` pattern.

Add `:manage_announcements` to `Emakola.Accounts.PlatformPermissions` (`@permissions`)
and an "Announcements" sidebar nav link (megaphone icon) in the platform layout.

## Audit

Add `:announcement_published` and `:announcement_canceled` to the
`PlatformAuditLog` `one_of` allowlist + severity colors in `audit_log_components.ex`
(`announcement_published` → green, `announcement_canceled` → amber). Log from the
LiveView after create/cancel via `PlatformAudit.log/4` with string-keyed metadata
(`announcement_id`, `title`).

## WhatsApp (shipped dark)

Add an `announcement` template to `Emakola.Notifications.Templates` /
`@template_param_order` (param: `title`). `AnnouncementDeliveryWorker` calls
`whatsapp_provider().send_message(number, "announcement", %{title: …}, …)`. Until Meta
approves the live template, the production provider returns
`{:error, {:unknown_template, …}}` (already logged, not sent) — the worker treats a
WhatsApp error like any channel failure (logs; a hard failure retries, but a
permanently-unknown template should be treated as a skipped channel so it never wedges
the job — see Edge cases). Test path uses the Log/Mox provider.

## Files

- `lib/emakola/notifications/resources/announcement.ex` (new)
- `lib/emakola/notifications/resources/announcement_dismissal.ex` (new)
- `lib/emakola/notifications/notifications.ex` (register + code interfaces)
- `lib/emakola/notifications/workers/announcement_publish_worker.ex` (new)
- `lib/emakola/notifications/workers/announcement_delivery_worker.ex` (new)
- `lib/emakola/notifications/templates.ex` (+ `announcement` template) — verify exact module
- `lib/emakola/accounts/platform_permissions.ex` (+ `:manage_announcements`)
- `lib/emakola/accounts/resources/platform_audit_log.ex` (+ 2 atoms)
- `lib/emakola_web/components/.../audit_log_components.ex` (+ severity colors)
- `lib/emakola_web/hooks/merchant_announcements.ex` (new) + register in `:app` live_session
- `lib/emakola_web/components/layouts/app.html.heex` (banner component)
- `lib/emakola_web/live/platform/announcement_live/index.ex` (new) + router `:platform` + platform nav

## Build sequence (each step: tests → implement → green)

1. `Announcement` + `AnnouncementDismissal` resources + code interfaces → resource tests
   (create defaults to `:scheduled`; `:active_for_store` derived query honors
   publish/expiry/status; cancel; dismissal uniqueness/upsert).
2. `AnnouncementPublishWorker` + `AnnouncementDeliveryWorker` → worker tests (publish
   flips status + enqueues one delivery per target store; audience `:active` filters
   dead stores; delivery sends via Log providers, skips missing contacts, tolerates
   unknown WhatsApp template; `:canceled`/already-published → no-op; idempotent).
3. `:manage_announcements` permission + audit atoms + colors → small unit assertions.
4. `MerchantAnnouncements` hook + banner → merchant LiveView test (sees active banner;
   dismiss hides it and persists; scheduled/expired/canceled not shown; dismissed not
   re-shown).
5. `Platform.AnnouncementLive.Index` + route + nav → platform LiveView test (form
   persists + enqueues publish worker + audit row; permission gating; cancel).
6. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`.

## Edge cases / risks

- **WhatsApp permanently-unknown template** must NOT wedge the delivery job forever
  (3 retries then dead). Treat `{:error, {:unknown_template, _}}` as a *skipped* channel
  (`:ok`-equivalent), distinct from a transient send error that should retry. Decide in
  step 2 and assert it.
- **Schedule in the past / immediate send:** `publish_at <= now` → Oban runs the publish
  worker immediately. Fine.
- **Cancel after publish:** banner stops (derived query excludes `:canceled`); external
  sends already dispatched can't be recalled — acceptable; document.
- **Large fan-out:** Ghana-scale store counts are small; per-store jobs are cheap and the
  `:notifications` queue concurrency bounds them.
- **`whatsapp_number` field:** confirm the Store attribute name during step 2 (some flows
  use `contact_phone` for SMS and a separate WhatsApp number).

## Verification (end-to-end)

**Automated (TDD):** resource, worker, hook/banner LiveView, platform LiveView tests as
above; `assert_enqueued worker: AnnouncementDeliveryWorker` per target store; audit row
asserted. Suite green + format + credo; own files compile warning-clean.

**Manual (after green):** as platform owner open `/platform/announcements`, create an
`:info` announcement to `:active` stores on channels `[:banner, :email, :sms]` with a
near-future `publish_at` → at publish_at the banner appears for a merchant, email/SMS go
out (Log provider in dev), dismiss hides it; set `expires_at` in the past → banner gone;
cancel a scheduled one → never publishes.

## Out of scope (v1)

Per-channel delivery receipts / read analytics; customer-facing announcements; rich
text / attachments; recurring or templated-campaign announcements; per-store hand-picked
targeting (only `:all` / `:active` segments for now).
