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

### SAF-3 — `Emakola.Suppliers.SupplierAction` boundary · `DONE`

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

### SAF-4 — `/supply/:token` LiveView · `DONE`

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

### SAF-5 — merchant reflection in `order_live/show.ex` · `DONE`

Ships with SAF-4 — the link is useless if the merchant cannot send it.
Sign links once in `load_fulfillments/1`. Accepted/declined lines. **Silence
"Resend" once `accepted_at` is set.** Copy link, Send on WhatsApp, New link.

### SAF-6 — `Referrer-Policy` header · `DONE`

One line in the `:browser` pipeline. Also closes the same live token leak on
`/pair/:token` and `/susu/:code`.

### SAF-7 — notification rail: the unconditional bugfixes · `DONE`

No flag, because these *reduce* sends:
- `blank?/1` guard — an empty-string `whatsapp_number` is truthy today, routes
  to WhatsApp with `""`, 400s at Meta, and never tries SMS
- `last_send_error` / `last_send_error_at` (label only, never the provider body)
- Return `{:error, _}` while retrying, `:ok` on the final attempt, writing the
  failure every time
- Merchant card: "Message not delivered" / "Add supplier phone number"
- Append the action URL to the SMS template and **delete "Reply to confirm"** —
  there is no inbound webhook, so it is a promise the system cannot keep

### SAF-8 — WhatsApp → SMS fallthrough · `BUILT, SHIPS DARK`

**Code complete and gated off.** `SUPPLIER_SMS_FALLBACK=true` turns it on with
`fly secrets set` — no code deploy. Default is **false** everywhere except test.

The gate covers only the paid channel. The blank-number guard, the recorded
failure and the merchant's "Message not delivered" card are ungated, because
they reduce sends rather than cause them. Tests cover both flag states,
including the one that protects the bill: WhatsApp fails, SMS available, gate
shut, `verify_on_exit!` proves nothing was sent.

**Before flipping it:**
1. Confirm at the SMS **provider's dashboard** that `SMS_API_KEY` is live and
   what a message costs. Never trust the app's `{:ok, _}`.
2. Size it: `select count(*) from fulfillments where supplier_id is not null
   and status = 'pending'` per week.

🔴 Prod does **not** fall back to `LogSMS` — `runtime.exs:282` wires
`Channels.SMS` unconditionally and raises at boot without `SMS_API_KEY`. Before
enabling: confirm at the **provider's dashboard** whether that key is live and
what a message costs, then size weekly volume. Do not trust the app's `{:ok, _}`.

### SAF-13 — the supplier can close the delivery loop · `DONE`

**The hole SAF-4 opened.** A supplier who ships direct through `/supply/:token`
reaches `:shipped` and the page dead-ends at a green tick. The delivery OTP —
the only release path in the system requiring a second party's assent — has
three legs, and the third does not exist:

| Leg | Who can ask | Scoped by | Entry point |
|---|---|---|---|
| Merchant → buyer | merchant | `store_id` | `CustomerDelivery` via `OrderLive.Show` |
| Wholesaler → merchant | that wholesaler | `linked_store_id` | `InboundFulfillment` via `SupplyNetworkLive` |
| **Off-platform supplier → buyer** | **nobody** | — | **none** |

The person at the buyer's door is the supplier or their rider, and the buyer
reads the code to *them*. Today only the merchant can enter it, remotely — which
puts the merchant back in the chase.

Add `request_delivery_code/1` and `verify_delivery/2` to
`Emakola.Suppliers.SupplierAction`, token-scoped, plus two screens on the
action page. **Resolved:** delegated the mechanics to `CustomerDelivery` rather than
writing a third copy. The token establishes *which* fulfilment the caller may
act on; the mechanics then run through the single existing implementation, so
the shared send budget is automatic rather than something to remember. Original
note kept below.

**Do not generalise the existing two modules** — `CustomerDelivery`
says it outright: the three differ precisely in *who is allowed to ask*, which
is the security boundary, and collapsing them puts that decision behind a flag.

🔑 **Share the rate-limit key with `CustomerDelivery`.** Both legs send an SMS to
the *same buyer* about the *same fulfilment*. Separate keys would let merchant
and supplier together fire 6 codes in ten minutes at one buyer's phone. Reusing
`delivery_otp:customer:#{fulfillment_id}` caps the buyer's exposure at 3
regardless of who asks — the limit belongs to the recipient, not the requester.

Other constraints:
- The supplier must **never** learn the code. `return_code: true` stays test-only.
- Only from `:shipped`, and only while the token is valid and unrevoked.
- Verification marks delivered, which releases the merchant's payout hold — the
  same consequence `InboundFulfillment.verify_delivery/4` already carries.
- The buyer's phone is already visible to the supplier post-accept, so
  triggering the SMS leaks nothing new.

**Acceptance:** a supplier can request a code, the buyer receives it, the
supplier enters what the buyer reads out, the fulfilment goes `:delivered`, and
the protection hold releases. A wrong code burns an attempt; five wrong codes
lock it; the merchant and supplier share one send budget.

### SAF-15 — harden the delivery-OTP primitive · `DONE`

Two findings on `FulfillmentDeliveryProof`. Both affect the **existing** legs,
not only the new one.

**F2 — the 5-attempt cap resets on every reissue.** `:reissue` sets
`attempts: 0` with no lifetime budget, so the cap is per-code, not per-proof. At
3 sends per 10 minutes that is 15 guesses per 10 minutes, unbounded over time —
~2,160/day against a 900,000 space. Add a lifetime issuance/attempt budget so
the cap means what it reads.

**F3 — `:reissue` clears `verified_at`.** A verified proof can be reset to
unverified. The only thing preventing a replay today is the
`status != :shipped` guard in `validate_code`; the proof record itself offers
none. Refuse to reissue a proof that has already been verified.

### SAF-14 — self-attested delivery becomes visibly second-best · `DONE`

**F1, decided by Kojo 2026-08-29: keep the escape hatch, make it leave a trail.**

`order_live/show.ex:678` lets a merchant mark any shipped fulfilment delivered
with no buyer assent, which stamps `release_after` and starts their own payout
clock. `CustomerDelivery`'s moduledoc names this as the hole the OTP was built
to close — the OTP landed, the button never left. It is **not** redundant with a
timer: `release_after` is stamped only on delivery, so there is no auto-release
path, and stale holds sit 30 days before manual staff review. Removing it would
strand honest merchants whose buyers do not answer.

So: OTP stays the prominent path; self-attest is demoted to a quiet secondary
action, records **who** attested and that it was **unverified**, and surfaces in
the platform protection queue so staff can sort on it.

---

## Phase 2 — the clock

### SAF-9 — SLA schema + stamping · `DONE`

`respond_by`, `escalation_level`, `escalated_at`. `StampSupplierRespondBy` on
`Order.:confirm`, before `NotifyConfirmation`.

🔴 **Do not backfill `respond_by`.** The first cron tick would escalate the
entire historical backlog at once. Put this in the migration comment.

### SAF-10 — `SupplierSlaWorker`, rung 1 only · `DONE`

Queue `:default`, cron `{"5,35 * * * *"}`, `unique: [period: 1500]` — the period
must stay strictly below the cron interval or every second run is swallowed
silently, and no `perform/1`-level test would catch it.

Candidate filter: `status in [:pending, :notified] and is_nil(accepted_at)` —
the `accepted_at` clause is the SAF-1 integration point.

### SAF-11 — escalation rungs 2–3 + merchant surface · `DONE`

`:supplier_overdue` notification type, bell + PubSub only (no merchant SMS —
kills the quiet-hours and cost problems together). Order LiveView subscribes to
`store:*:orders`. Decline sets `escalation_level: 3`.

### SAF-12 — `:void_unfulfilled` + "Cancel this part" · `DONE`

New action, not a relaxed `:void` — the existing one's `:platform_payout`
predicate is half the double-pay guard. Merchant tap, never automatic.


### SAF-16 — the merchant can SEE it without opening an order · `DONE`

The escalation was invisible where merchants actually look. The clock fired,
the bell rang, and `order_live/index.ex` showed nothing — so a merchant with
forty orders still had to open each one to find the stuck supplier, which is
the chasing the clock exists to end.

- `Order.:supplier_alert` calculation → `:blocked | :unreachable | :waiting |
  :accepted | nil`, most urgent wins. **Never raises** on an unfamiliar status,
  unlike `FulfillmentStatus`, which took down every order view the first time
  `:declined` appeared.
- Icon-led chip per row on the orders list; label hides below `sm:` and always
  sits in `title`.
- Fourth `work_tile` on the dashboard — "Suppliers not replying". Counted over
  fulfillments, not the calculation, because that is a filter Postgres can
  answer directly.
- The order detail card's six text-only lines are now icon-led and shorter,
  matching the register of the `/supply/:token` page next door.

---

## Build notes worth keeping

Things that cost time and would cost it again.

- **`f.supplier_id and ...` raises `BadBooleanError` in HEEx.** `supplier_id` is
  a UUID, and `and` demands a boolean on the left. `:if={f.supplier_id}` alone is
  fine (truthy), but the moment you combine it, write
  `not is_nil(f.supplier_id) and ...`.
- **`refute html =~ "375"` on a full LiveView render is a lottery ticket.** SVG
  path data is full of coordinates like `M3.375a1.125`, and the phx-session blob
  is random base64. Strip the markup and assert on visible text.
- **A `live` route's `:plug` is `Phoenix.LiveView.Plug`,** not the LiveView
  module — match on `:path` when pinning a route in a test.
- **`Phoenix.Token`'s `:signed_at` is in SECONDS.** Passing milliseconds dates
  the token ~55,000 years ahead and `verify` answers `:invalid`, not `:expired`.
- **`.html.heex` files need `mix format` too** — passing only the `.ex` paths to
  `mix format` leaves the co-located template unformatted and CI fails.
- **`for status <- [...] do test ... unquote(status)`** inlines the status as a
  literal, so a `case` over it has an unreachable clause and the compiler warns —
  and CI compiles tests with `--warnings-as-errors`. Write the tests out.
