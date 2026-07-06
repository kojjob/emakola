# Store KYC / Verification Workflow — Design

## Context

The `Store.verified` trust badge (shown on `/stores` directory cards) is set today by a manual platform toggle (`StoreLive.Index` `toggle_verified`, gated by `:manage_stores`) — there is no submission or review behind it. This feature makes KYC the real path to that badge: merchants submit identity/business details + documents, platform staff review and approve/reject, and approval awards `verified`.

Separately, `StorePayoutAccount.verification_status` is the **Paystack subaccount** check (set automatically by `dropship_settlement.ex`, already gating dropship payouts) — KYC does **not** touch it. Payouts are out of scope for v1.

Second feature from the platform-admin backlog after store lifecycle (`[[emakola-store-lifecycle]]`); reuses that feature's queue/detail + audit + notify patterns.

**Decisions (with user):** per-store subject · trust-badge-only (no payout gating) · structured fields + private document uploads · dedicated `/admin/verification` merchant page · reuse `:manage_merchants` permission · Ghana-focused `id_type` list.

Branch: `feature/store-kyc-verification`. TDD throughout (≥90% on new code).

## Data model — `Emakola.Stores.StoreVerification` (new resource)

Per-store, tenant-scoped (`strategy :attribute`, `attribute :store_id`, `global? true` so the platform queue reads across stores — same as `StorePageContent`). One row per store, created on first submission.

- `status` :atom `one_of [:pending, :approved, :rejected]`, `allow_nil? false` (no row = not submitted)
- `business_name` :string
- `id_type` :atom `one_of [:ghana_card, :passport, :drivers_license, :voter_id]`
- `id_number` :string
- `id_document_key` :string (private storage key, required on submit)
- `business_doc_key` :string (private storage key, optional)
- `review_reason` :string (rejection notes; nil otherwise)
- `submitted_at`, `reviewed_at` :utc_datetime_usec
- `identity :unique_store_verification, [:store_id]`

**Actions:**
- `:submit` (create) — merchant; accepts fields + keys; sets `status :pending`, stamps `submitted_at`.
- `:resubmit` (update) — merchant; only from `:rejected`; replaces fields/keys, clears `review_reason`, → `:pending`, re-stamps `submitted_at`. Enqueues `StorageCleanupWorker` for replaced doc keys.
- `:approve` (update) — platform-only; → `:approved`, stamp `reviewed_at`.
- `:reject` (update) — platform-only; accepts `review_reason` (required), → `:rejected`, stamp `reviewed_at`.
- Reads: `:get_by_store` (arg store_id), `:list_for_review` (arg status filter, sorted submitted_at; global).

**Policies:** Merchant actor with store access may submit/resubmit/read own (mirror `StorePageContent`). `:approve`/`:reject` are **platform-only**: `policy action([:approve, :reject]) do forbid_if(always()) end` + always called `authorize?: false` from the LiveView (same convention as the store lifecycle actions). Code interfaces in `lib/emakola/stores/stores.ex`.

## Merchant submission — `/admin/verification` (`EmakolaWeb.Admin.VerificationLive`)

In the `:app` live_session. Loading-shell (no DB on disconnected mount). Shows current status:
- none → submission form; `:pending` → "under review" (read-only); `:rejected` → reason + resubmit form; `:approved` → confirmation.

Two private uploads via `allow_upload(:id_document, ...)` (required) + `allow_upload(:business_doc, ...)` (optional), `accept ~w(.jpg .jpeg .png .pdf)`, `max_file_size 10MB`. On submit: `consume_uploaded_entries` → `Emakola.Storage.upload(binary, key, acl: "private", content_type: ...)` with `key = "verifications/<store_id>/<slot>-<uuid>.<ext>"` → `Stores.submit_store_verification/resubmit`. Audit `:verification_submitted`. Link added from dashboard/settings.

## Admin review queue (`:manage_merchants`)

- `/platform/verifications` → `Platform.VerificationLive.Index`: list (default `:pending`, filterable), loading-shell, link to detail. New "Verifications" sidebar nav (gated `:manage_merchants`).
- `/platform/verifications/:id` → `Platform.VerificationLive.Show`: fields + **document links as short-lived presigned URLs** (`Storage.presigned_url(key, expires_in: 900)`); **Approve** / **Reject** buttons → reason-modal (reject requires reason) → `authorized/2` re-check (`:manage_merchants`) → action + audit + notify; lifecycle history from the audit log (`list_for_store` filtered to verification actions).

## Effects, audit, notify

- Approve → `:approved` **and** `Stores.update_store_directory_meta(store, %{verified: true}, authorize?: false)`. Reject → `:rejected`; set `verified: false` defensively.
- Audit atoms added to `PlatformAuditLog` `one_of`: `:verification_submitted`, `:verification_approved`, `:verification_rejected`. Metadata `%{"store_id", "store_name", "reason"}`.
- New `Emakola.Notifications.Workers.VerificationStatusNotificationWorker` (mirror `StoreStatusNotificationWorker`: queue `:notifications`, `unique [period: 600]`, self-contained `enqueue/2`, SMS+email to the store's contacts, propagate delivery errors). Events `:verification_approved | :verification_rejected`. Submission does not notify (reviewers watch the queue).

## Existing-code touch points

- `lib/emakola/stores/resources/store_verification.ex` (new) + `lib/emakola/stores/stores.ex` (interfaces)
- `lib/emakola/accounts/resources/platform_audit_log.ex` (+3 atoms) + `audit_log_components.ex` (severity colors)
- `lib/emakola_web/live/admin/verification_live.ex` (new) + router `:app` + dashboard/settings link
- `lib/emakola_web/live/platform/verification_live/{index,show}.ex` (new) + router `:platform` + sidebar nav
- `lib/emakola/notifications/workers/verification_status_notification_worker.ex` (new)
- migration via `mix ash.codegen add_store_verification` (trim unrelated snapshot drift — `[[emakola-store-lifecycle]]` lesson)

## Build sequence (each step: tests → impl → green)

1. `StoreVerification` resource + actions + policies + migration + code interfaces → resource tests (submit/resubmit/approve→verified/reject; platform-only policy).
2. Audit atoms + `audit_log_components` colors.
3. `VerificationStatusNotificationWorker` + tests.
4. Merchant `/admin/verification` page + private upload + Storage acl:private → LiveView tests (upload→pending, rejected→resubmit).
5. Platform queue Index + Show (presigned doc links, approve/reject modal, audit, notify) + sidebar nav → LiveView tests (permission gating, approve sets verified + audit + enqueue, reject reason).
6. Dashboard/settings link.
7. Verification: `mix test`, `mix format --check-formatted`, `mix credo --strict`.

## Verification (end-to-end)

Automated: resource action tests; worker test; merchant LiveView (upload→pending via `Phoenix.LiveViewTest` + `Plug.Upload`); platform LiveView (`setup_platform_staff` owner + `permissions: [:manage_merchants]`; assert approve sets `store.verified`, audit row, `assert_enqueued` for the worker; reject requires reason; staff without `:manage_merchants` redirected). Suite green + format + credo.

Manual: as merchant, submit at `/admin/verification` (upload a test image) → pending; as platform staff, open `/platform/verifications/:id`, view the doc via the signed link, approve → merchant store shows `verified` badge on `/stores`, merchant gets notified, status shows approved.
