# Communications plan — reach people the way they actually communicate

**Decided 2026-08-24 with Kojo.** Two problems, one plan:

1. **Email is the wrong default.** Most Makola merchants and buyers do not use
   email. Password reset is currently email-only, so a merchant without an
   email address **cannot recover their account at all**.
2. **Per-message cost.** Every SMS is billed to the merchant. In-house
   messaging removes that cost for conversations that do not need to leave
   the platform.

**Channel decision (2026-08-24):** no Twilio. SMS via a local aggregator —
Arkesel (already spoken natively by `Channels.SMS`) or Hubtel (already
integrated for payments). Twilio to Ghana is ~10× local rates and the merchant
pays it. WhatsApp direct via Meta Cloud API rather than through a BSP markup.

**Messaging scope (Kojo, 2026-08-24): BOTH** — merchant ↔ their buyers, and
Makola ↔ merchants, over one shared thread/message core.

---

## Phase A — Reach the person by the channel they have

- [x] **A0. ✅ Make email optional on `Customers.Customer`.** *(found 2026-08-24
      while writing A1)* `email` is `allow_nil?(false)`, so a buyer cannot
      exist without one — and the WhatsApp signup still asks for an email
      because the attribute forbids nil. Phone-first signup is not actually
      possible today. Email becomes optional, with a validation that a
      customer must have **a phone or an email** so nobody is created
      unreachable.
- [x] **A1. Channel resolver.** ✅ `Emakola.Notifications.Reach` — 10 tests. `Emakola.Notifications.Reach`: given a
      customer or merchant, return the ordered channels that will actually
      reach them (whatsapp → sms → email), honouring `marketing_opt_out_at`
      for marketing and ignoring it for transactional. Never assume email.
- [x] **A2. ✅ Route existing notifications through it.** Order, shipping and
      delivery notifications currently branch on their own. One resolver, so
      a merchant with no email stops silently missing messages.
- [x] **A3. ✅ Phone-based account recovery.** The lockout fix.
      `Accounts.PhoneAuth` (OTP request/verify, E.164 normalisation) is
      already built and ship-dark behind `PHONE_AUTH_ENABLED`; wire it into
      the forgot-password flow so recovery does not require email.

## Phase B — In-house messaging core (shared by both directions)

- [x] **B1. ✅ Thread + Message resources.** One core: a thread has a subject,
      a kind (`:shop_buyer` | `:platform_merchant`), participants, and
      messages. Store-scoped for shop threads.
- [ ] **B2. Merchant ↔ buyer threads.** Attached to an order where one
      exists, standalone otherwise. Buyer writes from the storefront account
      area; merchant replies from the admin.
- [ ] **B3. Makola ↔ merchant support inbox.** Platform staff open a thread
      with a merchant; merchant sees and replies in the admin. Extends
      Announcements from broadcast to conversation.
- [ ] **B4. Unread counts + realtime.** PubSub per thread, unread badge in
      both admins. Streams, not assigns (a thread grows).
- [ ] **B5. Notify only when needed.** A new in-app message notifies via the
      A1 resolver **only if unread after a delay** — otherwise every message
      costs an SMS and defeats the point.

## Guardrails carried from tonight

- Counts and states shown must be measurable. No opens, no read receipts we
  do not receive.
- No control that does not work; no invented data in any state.
- Money-touching fan-outs claim before they send (see `CampaignSendWorker`).
- Every step lands TDD, on its own branch off `main`, with the full gates.

## Status log

- 2026-08-24 — plan written.
- 2026-08-24 — **A1 done**: `Notifications.Reach` (whatsapp → sms → email;
  opt-out suppresses marketing only, never transactional). 10 tests.
- 2026-08-24 — **A0 raised** while writing A1, and it is bigger than it looks:
  `Customer.email` is `allow_nil?(false)`, 57 call sites read `customer.email`,
  and AshAuthentication's password strategy depends on the `:unique_email`
  identity. Needs its own branch and a call-site audit — not a tail-end change.
- 2026-08-24 — **A0 done**: `Customer.email` optional + `ContactDetailPresent`
  (a customer needs a phone OR an email, so nobody is created unreachable) +
  migration. Audit result: all three email builders are reached only through
  `send_customer_email`, already behind `if customer && customer.email` — the
  email path was already nil-safe. Pinned with a phone-only regression test,
  the shape that could not exist before. Full suite 6990 → green.
- 2026-08-24 — **A2 done**: `OrderNotificationWorker` now asks
  `Reach.channels_for/2` instead of re-implementing "do they have a phone".
  A hypothesised blank-phone bug turned out NOT to exist — a blank phone is
  normalised to nil on write, so the test written for it passed vacuously and
  was deleted rather than kept as a guard over nothing.
- 🔴 **Open cost question for Kojo:** every buyer event currently sends BOTH
  WhatsApp *and* SMS when a phone exists — two paid messages per notification.
  Reach's ordering would support whatsapp-first-with-sms-fallback, halving it,
  but WhatsApp can fail silently without an approved template, and then the
  buyer gets nothing. Behaviour deliberately left unchanged pending that call.
- 2026-08-24 — **A3 done**: `Accounts.PhoneRecovery` + `/auth/recover-phone`,
  linked from the email page ("No email? Use your phone number"). An unknown
  number is indistinguishable from a known one (otherwise the form enumerates
  merchants' phone numbers); a code is single-use; a reset revokes every
  existing session. **Phase A complete.**
- ⚠️ Test trap worth remembering: `PhoneAuth` rate-limits sends PER NUMBER, so
  tests sharing one phone exhaust the window and a later test silently gets no
  code — which reads as a broken feature, not a noisy test. Give each test its
  own number.
- 2026-08-24 — **B1 done**: `Emakola.Conversations` — Thread (both kinds) +
  Message, 11 tests. Unread is two timestamps per thread, not a receipts table
  (one row instead of one row per message per reader).
- ⚠️ Postgres note: the thread uniques are PLAIN, not partial. A partial unique
  index cannot be an `ON CONFLICT` target (42P10), which breaks the upsert that
  makes `open_*_thread` idempotent. Plain works because Postgres treats NULLs
  as distinct, so platform threads (NULL store/customer) and shop threads
  (NULL merchant) each coexist while true duplicates are still refused.
- **Next: B2** (merchant ↔ buyer UI), then B3/B4/B5.
