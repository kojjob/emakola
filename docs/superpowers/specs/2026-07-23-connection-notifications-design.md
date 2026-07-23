# Supply Connection Notifications — Design

**Date:** 2026-07-23
**Status:** Approved
**Owner ask:** Close the connection loop — the wholesaler hears about new
requests, the reseller hears the decision, on SMS + WhatsApp + push.

## Context

`Network.request/approve/reject` currently fire no notifications: a reseller
requests a connection from the Supplier Catalog and the wholesaler only finds
out by visiting the Earn Network page; the reseller waits blind for the
decision. Sub-project 2 of the supplier-marketplace sequence (after the offer
management UI, before charging dispatch fees at checkout).

Decisions locked with Kojo:

- Channels: **all three** — SMS + WhatsApp + in-app push.
- Events: **request → wholesaler; approval → reseller; rejection → reseller.**
  Suspend/terminate/reactivate stay silent (rare admin actions, visible in UI).

## 1. Worker

New `Emakola.Notifications.Workers.ConnectionNotificationWorker` (Oban,
`:notifications` queue if that is what sibling workers use — mirror
`SupplierNotificationWorker`'s queue/retry settings):

- Args: `%{"connection_id" => id, "event" => "requested" | "approved" | "rejected"}`.
- Oban uniqueness on `(connection_id, event)` args (idempotent; re-enqueues
  and retries cannot double-send within the uniqueness window).
- Perform: load the `SupplyConnection`; resolve recipients (§2); send on each
  channel best-effort (§3); log per-channel outcomes. Missing connection or
  zero recipients → log + `:ok` (no retry into a void). The job returns `:ok`
  if the fan-out ran, regardless of individual channel failures — matching
  the delivery posture of the existing notification workers.

## 2. Triggers & recipients

`Emakola.Suppliers.Network` enqueues AFTER the domain write succeeds:

| Service call | Event | Recipients |
|---|---|---|
| `request/2` | `"requested"` | wholesaler store's owner-role members |
| `approve/2` | `"approved"` | reseller store's owner-role members |
| `reject/2` | `"rejected"` | reseller store's owner-role members |

Recipients = merchants via `StoreMembership` (role `:owner`) for the target
store. Per-recipient contact: `merchant.phone` for SMS/WhatsApp (silently
skip a channel when the phone is missing — same posture as
`SupplierNotificationWorker`); push targets the store's device tokens exactly
as `PushNotificationWorker` resolves them. A failed enqueue must not fail the
service call (log and continue — notifications are best-effort, the domain
write already succeeded).

## 3. Channels & copy

Copy lives in `Emakola.Notifications.Templates` beside the order copy.
Store names come from the loaded connection's store relationships.

- **SMS** (via `Emakola.Notifications.Channels.SMS`):
  - requested: `"{reseller} wants to stock your products. Review the request
    on your Earn Network page: {url}"`
  - approved: `"{wholesaler} approved your connection. Wholesale pricing is
    now visible in your Supplier Catalog: {url}"`
  - rejected: `"{wholesaler} declined your connection request. You can browse
    other suppliers in the Supplier Catalog: {url}"`
  - URLs point at `/admin/settings/supply-network` (requested) and
    `/admin/supply/catalog` (approved/rejected), absolute via the endpoint
    host helper the order SMS copy uses.
- **WhatsApp** (via the existing WhatsApp channel/behaviour): one new
  business-initiated template `supply_connection_update` with variables
  (counterparty store name, event phrase, destination URL). **Ships dark
  until Meta approves the template** — the channel send is attempted and
  logs the provider rejection until then; SMS carries day one. The template
  joins the LAUNCH_TODO WhatsApp submission list.
- **Push** (via `Emakola.Notifications.PushProvider` — the
  `PushNotificationWorker` pattern): title/body per event (e.g. "New supply
  request" / "{reseller} wants to stock your products"), data payload with
  `connection_id` and event.

One channel failing never blocks the others (each send individually
rescued/logged, mirroring `SupplierNotificationWorker`).

## 4. Error handling

- Connection deleted/missing at perform → log + `:ok`.
- Zero owner members or no contact data → log + `:ok` per channel skipped.
- Provider errors → per-channel log; job still `:ok`.
- Service-side enqueue failure → log; the request/approve/reject result is
  unchanged.

## 5. Testing (TDD, tests first)

Worker (Mox for SMS/WhatsApp/push providers):
- Per event: right recipients (wholesaler owners for requested, reseller
  owners for approved/rejected), copy contains the counterparty store name.
- Missing phone → SMS/WhatsApp skipped, push still attempted.
- One channel raising → others still sent, job returns `:ok`.
- Missing connection → `:ok`, nothing sent.

Service (Oban.Testing):
- `request/approve/reject` each enqueue exactly their event with the right
  connection id — assert with `all_enqueued` counts (never returned job ids;
  Oban unique-conflict returns the attempted job — known repo gotcha).
- Failed enqueue does not change the service result.

LiveView seal:
- Requesting a connection from the catalog Show page enqueues the
  `"requested"` job (drives the real button).

## Out of scope

- Suspend/terminate/reactivate notices; email channel; a notification-feed
  UI; per-merchant notification preferences; charging dispatch fees
  (sub-project 3).
