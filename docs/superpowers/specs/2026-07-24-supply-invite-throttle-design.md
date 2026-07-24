# Supply-Connection Invite Throttle — Design

**Date:** 2026-07-24
**Status:** Approved (limits locked with Kojo: 10/day + 3/min per store)
**Why now:** each connection invite fires SMS + WhatsApp + push at the target
store's owner. Real Arkesel/Meta keys are about to go in; an unthrottled
invite form is a cost and reputation hole. Ships before real SMS keys.

## Threat model

Duplicate invites to the same target are already impossible —
`ensure_connection_absent/2` allows one `SupplyConnection` row per
(wholesaler, reseller) pair forever, including rejected. The remaining
vector is fan-out: one merchant inviting many distinct stores. Bound it
per requesting store.

## Mechanism

In `Emakola.Suppliers.Network.request/2`, after the existing validations
(access, stores-must-differ, connection-absent) and immediately before the
create, check two `Emakola.RateLimit` (Hammer/ETS) counters keyed by the
requesting store — burst FIRST so a burst-denied attempt does not consume
a daily slot:

1. `"supply_invite:burst:{store_id}"` — 3 per 60_000 ms
2. `"supply_invite:day:{store_id}"` — 10 per 86_400_000 ms

Either `{:deny, _}` returns `{:error, :invite_rate_limited}`: no row
created, no notification job enqueued. Limits are module attributes in
`network.ex` — no config, no env vars.

Running the check after validation means typo'd slugs and duplicate
invites never burn quota (they short-circuit earlier in the LiveView or
in `request/2` itself).

## UI

`request_connection` in `EmakolaWeb.Admin.SupplyNetworkLive` gets one new
error branch:

- `{:error, :invite_rate_limited}` → flash error
  "Invite limit reached — please try again later."

## Testing

- Network level: 4th request inside a minute denied (3 distinct partner
  stores succeed first); daily limit tested by pre-loading the day
  counter with 10 direct `RateLimit.check_rate/3` hits, then one real
  request denied; a denied request creates no `SupplyConnection` and
  enqueues no `ConnectionNotificationWorker` job.
- LiveView: seeded-counter denial renders the flash.
- Flake guard (PR #174 lesson): keys embed the test's fresh `store_id`,
  so every test starts in an empty Hammer bucket; assertions must not
  straddle a window boundary.

## Out of scope

Approve/reject/suspend notifications (bounded by invites received);
platform-admin override knobs; persistence of counters across deploys
(ETS reset on restart is acceptable at this scale).
