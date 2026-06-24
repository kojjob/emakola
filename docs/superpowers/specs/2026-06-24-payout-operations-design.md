# Payout Operations (History + Retry + Notify) — Design

## Context

The payout-execution engine (#210/#211) can disburse a store's held balance, but it has no
operational surface: approving a payout immediately drops the store's "outstanding" to zero
(the charges are stamped), so a `pending`/`processing`/`failed` payout is **invisible**, and a
`:failed` payout has no retry control. Merchants also aren't told when they're paid.

This adds the operations layer on `/platform/finance` (gated `:manage_billing`). One PR, TDD.

## 1. Payout history — "Recent payouts" section on the Finance page

A table below the per-store breakdown: Store · Amount · Status pill
(`pending`/`processing`/`paid`/`failed`) · Date. This is where an in-flight or failed payout
becomes visible (fixing the post-approval blind spot).

- `Payout` resource: add `read :list_recent` (`prepare build(sort: [inserted_at: :desc],
  limit: 50)`) + a `belongs_to :store` (define_attribute?: false — `store_id` already exists; no
  migration) so names load via `load: [:store]`.
- Code interface `list_recent_payouts`.
- `FinanceLive.load/1` also assigns `payouts: list_recent_payouts(load: [:store])`.

## 2. Retry failed payouts

A "Retry" button on `:failed` rows → `handle_event("retry_payout", %{"payout_id" => id})`:
gate with `authorized/2` (`:manage_billing`, re-checked vs a fresh user) → re-enqueue
`PayoutWorker.enqueue(id)` (it already re-attempts a `:failed` payout idempotently via the same
`transfer_reference`) → `PlatformAudit.log(:payout_retried, …)` → reload + flash. Add
`:payout_retried` to the `PlatformAuditLog` allowlist.

## 3. Merchant paid-notification

`Emakola.Notifications.Workers.PayoutNotificationWorker`, mirroring
`StoreStatusNotificationWorker`:
- `use Oban.Worker, queue: :notifications, max_attempts: 3, unique: [period: 600, fields: [:args]]`.
- `enqueue(payout_id)` — args `%{"payout_id" => id}` (keyed on payout, so two payouts to the
  same store don't dedupe each other; re-fired webhook can't double-notify).
- `perform/1`: load the payout (`get_payout`, missing → `:ok`); load its store; build
  `Templates.payout_paid_merchant_sms(payout, store)`; send SMS to `store.contact_phone` (via
  `sms_provider().send_sms(phone, msg, store_id: store.id)`) and email to `store.contact_email`
  (Swoosh + `Emakola.Mailer`); skip a missing contact gracefully; fail the job only if an
  attempted channel errors.
- `Templates.payout_paid_merchant_sms/2` → e.g. `"#{store.name}: you've received
  #{format} from Makola. Payout complete."` (amount formatted from minor units).
- **Callsite:** in the webhook payout finalizer, after a payout flips to `:paid`, call
  `PayoutNotificationWorker.enqueue(payout.id)` — in the async `PaystackWebhookHandler` (prod
  path; the `finalize_payout` `:paid` branch) and the sync `PaystackWebhook` dispatcher.

## Out of scope
Un-stamp/reclaim a permanently-dead payout (charges back to the backlog) — `:failed` stays
retryable; reversal is later. WhatsApp payout template (SMS+email suffice). Bank-account payouts
(MoMo-only).

## Build sequence (tests → impl → green)
1. `Payout.list_recent` + `belongs_to :store` + `list_recent_payouts` interface → resource test
   (returns recent desc, loads store).
2. `PayoutNotificationWorker` + `Templates.payout_paid_merchant_sms` → worker test (SMS + email
   sent with the amount; missing contact skipped; attempted-channel error fails). Wire the
   `enqueue` into both webhook finalizers → webhook test asserts `assert_enqueued` on
   `transfer.success`.
3. Finance page: "Recent payouts" table + status pills + retry button + `retry_payout` handler +
   `:payout_retried` audit atom → LiveView test (renders payouts, retry re-enqueues + audits +
   gated, failed-only button).
4. Verify: `mix test`, `mix format --check-formatted`, `mix credo --strict`, new/changed files
   clean under `--warnings-as-errors` (incl. every new TEST file). PR.
