# Automated Fulfilment by Suppliers — Tickets

Plan: `~/.claude/plans/automated-fulfilment-by-suppliers-prancy-acorn.md`
Branch: `feature/supplier-action-link`

Status key: `TODO` · `WIP` · `DONE` · `BLOCKED`

---

## Phase 1 — the supplier can act

Ships value with **both** notification rails dead, because the delivery
mechanism is the merchant pasting the link into their own WhatsApp.

### SAF-1 — Fulfillment supplier state + the four crash consumers · `DONE`

Widen the state machine and land every consumer that pattern-matches the status
enum **in the same commit** — two of them raise at runtime otherwise.

- [x] `accepted_at`, `declined_at`, `decline_reason`, `supplier_link_version`
- [x] `status` `one_of` gains `:declined`
- [x] `:supplier_accept` (timestamp only, idempotent), `:supplier_decline`,
      `:rotate_supplier_link`
- [x] Widen `:mark_shipped` and `:cancel` to include `:declined`, **both**
      `StatusGuard` and `RequireStatusIn` layers
- [x] Code interfaces in `lib/emakola/orders/orders.ex`
- [x] Hand-written migration (no backfill, no rewrite)
- [x] `calculations/fulfillment_status.ex` — `@progress` head-insert `:declined`
      (confirmed **raising** before the fix)
- [x] `supply_network_live/presentation.ex` — `fulfillment_status_classes(:declined)`
      (confirmed **FunctionClauseError** before the fix; the new test derives the
      status list from the resource so the next addition cannot slip through)
- [x] `refund_reconciliation.ex` — `@active_fulfillment_statuses` gains `:declined`
- [x] `order_live/show.ex` — `:declined` badge class

**Acceptance:** `fulfillment_supplier_action_test.exs` green; a declined
fulfilment renders on the order page, the supply-network page, and survives a
full refund without raising.

### SAF-2 — `EmakolaWeb.SupplierLinkTokens` · `DONE`

`Phoenix.Token` over `[fulfillment_id, version]`, own salt, 30-day `max_age`,
modelled on `EmakolaWeb.TrackingTokens`. Rejects any other payload shape.

**Acceptance:** round-trip; wrong salt rejected; `nil`/`""`/garbage return
errors rather than raising; expiry honoured; map or 3-element payload → `:invalid`.

### SAF-3 — `Emakola.Suppliers.SupplierAction` boundary · `WIP`

`authorize/1`, `accept/1`, `decline/2`, `mark_sent/2`, `action_url/1`. **Every
function takes the token, never a fulfilment id.**

- `authorize/1` filters `not is_nil(supplier_id)` — a `nil`-supplier group is
  the merchant's own stock and must never be actionable from a public URL
- Version mismatch → `:revoked_token`
- Rate limit **per fulfilment** (`peer_data` is nil in a disconnected mount)
- Ash errors mapped to atoms, never leaked
- `decline/2` notifies the merchant via `notify_store/3` after commit
- **Leave `InboundFulfillment` alone** — different auth model

**Acceptance:** the security suite in the plan, including a hand-forged token
for a `supplier_id: nil` group returning `:not_found`.

### SAF-4 — `/supply/:token` LiveView · `TODO`

> **First:** `SELECT id, slug FROM stores WHERE slug = 'supply';` — if it
> returns a row, route `/ship/:token` instead. Dev DB checked 2026-08-29: clean
> for both `supply` and `ship`. ⚠️ **Still must be re-run against PROD before
> merge** — dev is not authority for which slugs real merchants have taken.

Six-screen fold. No money rendered, ever. Address staged: town pre-accept, full
details after. Three distinct event names, `Map.get` not head-destructure.
Photos lead, `min-h-16` buttons, inline SVG icons, `JS.hide/show` confirm.

**Acceptance:** offer screen contains no buyer name/street/phone and no money
string; accepted screen does show the address; `render_submit(view, "mark_sent", %{})`
does not crash.

### SAF-5 — merchant reflection in `order_live/show.ex` · `TODO`

Ships with SAF-4 — the link is useless if the merchant cannot send it.
Sign links once in `load_fulfillments/1`. Accepted/declined lines. **Silence
"Resend" once `accepted_at` is set.** Copy link, Send on WhatsApp, New link.

### SAF-6 — `Referrer-Policy` header · `TODO`

One line in the `:browser` pipeline. Also closes the same live token leak on
`/pair/:token` and `/susu/:code`.

### SAF-7 — notification rail: the unconditional bugfixes · `TODO`

No flag, because these *reduce* sends:
- `blank?/1` guard — an empty-string `whatsapp_number` is truthy today, routes
  to WhatsApp with `""`, 400s at Meta, and never tries SMS
- `last_send_error` / `last_send_error_at` (label only, never the provider body)
- Return `{:error, _}` while retrying, `:ok` on the final attempt, writing the
  failure every time
- Merchant card: "Message not delivered" / "Add supplier phone number"
- Append the action URL to the SMS template and **delete "Reply to confirm"** —
  there is no inbound webhook, so it is a promise the system cannot keep

### SAF-8 — WhatsApp → SMS fallthrough · `BLOCKED` (cost gate)

Behind `Application.get_env(:emakola, :supplier_sms_fallback, true)`.

🔴 Prod does **not** fall back to `LogSMS` — `runtime.exs:282` wires
`Channels.SMS` unconditionally and raises at boot without `SMS_API_KEY`. Before
enabling: confirm at the **provider's dashboard** whether that key is live and
what a message costs, then size weekly volume. Do not trust the app's `{:ok, _}`.

---

## Phase 2 — the clock

### SAF-9 — SLA schema + stamping · `TODO`

`respond_by`, `escalation_level`, `escalated_at`. `StampSupplierRespondBy` on
`Order.:confirm`, before `NotifyConfirmation`.

🔴 **Do not backfill `respond_by`.** The first cron tick would escalate the
entire historical backlog at once. Put this in the migration comment.

### SAF-10 — `SupplierSlaWorker`, rung 1 only · `TODO`

Queue `:default`, cron `{"5,35 * * * *"}`, `unique: [period: 1500]` — the period
must stay strictly below the cron interval or every second run is swallowed
silently, and no `perform/1`-level test would catch it.

Candidate filter: `status in [:pending, :notified] and is_nil(accepted_at)` —
the `accepted_at` clause is the SAF-1 integration point.

### SAF-11 — escalation rungs 2–3 + merchant surface · `TODO`

`:supplier_overdue` notification type, bell + PubSub only (no merchant SMS —
kills the quiet-hours and cost problems together). Order LiveView subscribes to
`store:*:orders`. Decline sets `escalation_level: 3`.

### SAF-12 — `:void_unfulfilled` + "Cancel this part" · `TODO`

New action, not a relaxed `:void` — the existing one's `:platform_payout`
predicate is half the double-pay guard. Merchant tap, never automatic.
