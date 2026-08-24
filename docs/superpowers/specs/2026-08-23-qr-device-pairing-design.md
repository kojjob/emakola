# Scan to sign in a phone — design

QR Phase 4. Deliberately its own document: this is a change to how someone
becomes authenticated, not a QR feature. The QR is incidental — a transport for
a token. Everything that matters is the token's lifecycle.

## The problem worth solving

Makola merchants often read poorly. A password is the single worst control the
product asks them for: long, case-sensitive, unreadable when masked, and typed
on a phone keyboard. Merchants respond the way anyone would — short passwords,
reused passwords, passwords written on the stall wall.

"Sign in on the desktop, scan with the phone" removes the phone-side typing.
That is the whole benefit, and it is real.

## Why this cannot be folded into the QR work

Platform auth is deliberately hardened today:

- Sessions are DB-backed (`Emakola.Accounts.UserSession`), verified on every
  request, and revocable.
- Idle timeout is 24 hours (`Emakola.Accounts.Sessions`, `@idle_timeout_hours`),
  with `last_seen_at` touched at 5-minute granularity.
- Platform staff carry mandatory TOTP on top of a password.

A pairing QR adds a path where **possession of an image equals a session**.
A code displayed on a laptop in a shared workspace, photographed over a
shoulder, screenshared, or left on screen while the merchant serves a customer,
is a bearer credential in the open. Nothing else in this system has that
property.

That is not a reason to refuse it. It is the reason it gets its own review.

## Threat model

| Threat | Why it is credible here | Mitigation |
|---|---|---|
| Shoulder capture | A stall is a public place; the screen faces outward | Short TTL; confirmation on the authenticated device |
| Screenshare / recorded demo | Merchants are onboarded over video calls | Short TTL; single-use |
| Replay of a used code | The image persists after use | Single-use, atomically consumed |
| Code harvested and used later | Photos live in camera rolls | Absolute expiry independent of use |
| Phishing: attacker shows *their* code to a merchant | The merchant scans, attacker's device gets the merchant's session | **Confirmation step naming what is being authorised** |
| Brute-forcing the token | Tokens are guessable if short | ≥128 bits of entropy, rate-limited redemption |

The phishing row is the one most easily missed and the most damaging: it inverts
the flow. The merchant scans a code an attacker controls, and the attacker's
browser gets signed in **as the merchant**. Every other mitigation is useless
against it. Only an explicit confirmation on an already-trusted surface —
naming the device and location being authorised — defeats it.

## Design

### Shape

1. Merchant is signed in on device A (desktop). They open "Sign in my phone".
2. Server mints a **pairing request**: random token, `pending`, TTL 90 seconds,
   bound to the requesting user and session.
3. Device A renders the token as a QR and polls (or subscribes) for status.
4. Merchant scans with device B. Device B opens a page carrying the token and
   **does not sign in**. It shows what is being requested and asks device B to
   confirm.
5. Device A shows a confirmation prompt naming device B (user agent, coarse
   location/IP) and requires an explicit tap.
6. On confirmation, the token is atomically consumed and a session is created
   for device B via the existing `Sessions.create/3`.

Step 5 is the load-bearing one. Without it the flow is phishable in both
directions.

### Resource

`Emakola.Accounts.DevicePairing`, tenant-free (it authenticates a user, not a
store):

| Field | Notes |
|---|---|
| `token_hash` | Bcrypt, `sensitive?: true, public?: false` — never store plaintext, mirroring `FulfillmentDeliveryProof` |
| `user_id` | who the pairing would authenticate |
| `origin_session_id` | the already-authenticated session that requested it |
| `status` | `:pending \| :confirmed \| :consumed \| :expired \| :rejected` |
| `expires_at` | 90 seconds from issue |
| `requested_by` | coarse device description of B, captured at scan |
| `confirmed_at`, `consumed_at` | audit |

Precedent to follow, not reinvent:

- **Hash, never store plaintext** — `Emakola.Orders.CustomerDelivery` already
  establishes this for a code a second party must present.
- **Atomic single-use consumption** — `SELECT … FOR UPDATE` inside a
  transaction, exactly as `CustomerDelivery.verify_delivery/3` does, so two
  concurrent redemptions cannot both succeed.
- **Rotation on exchange** — `Emakola.Accounts.ApiTokens` already revokes the
  presented token's jti on every exchange.

### Rules

- **TTL 90 seconds**, absolute, independent of use. Long enough to walk a phone
  over, short enough that a photograph is worthless by the time it is off the
  device.
- **Single-use**, consumed atomically under a row lock.
- **Confirmation on device A**, naming device B. Non-skippable.
- **Rate limit** pairing requests per user and redemptions per token (reuse
  `Emakola.RateLimit`).
- **Audit every transition** to `Emakola.Accounts.PlatformAudit` for staff, and
  the merchant equivalent otherwise. A pairing is a sign-in; it belongs in the
  same log.
- **Revoking the origin session revokes any pending pairing it minted.** A
  merchant who signs out on the desktop must not leave a live pairing behind.

### Scope

**Merchants only, at least initially.** Platform staff carry mandatory TOTP
precisely because their blast radius is the whole platform; a pairing flow that
bypasses the second factor would undo that deliberately. If staff pairing is
ever wanted, it must require TOTP on device B, which removes most of the
benefit — so the honest answer is that this feature is for merchants.

## What this does not do

- It does not replace the password. It is a second way in, so the password
  remains the recovery path and remains attackable. Pairing improves daily
  ergonomics, not credential strength.
- It does not help a merchant who has no second signed-in device. The first
  sign-in on any device still needs the password.

## Open questions for review

1. Is 90 seconds right? Shorter is safer; a merchant fumbling with a camera in a
   busy market may need longer. Worth testing with a real merchant before fixing.
2. Should device B's page show the merchant's shop name before confirmation?
   It confirms to the merchant that they scanned the right code — and it leaks
   the shop name to anyone who scans a stray code.
3. Should pairing be opt-in per store, given some merchants share a stall phone?

## Recommendation

Build it, merchants only, with the device-A confirmation step non-negotiable.
Without that step this is a phishing primitive, and I would rather ship no
pairing than pairing without it.
