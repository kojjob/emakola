# Provider Setup — Step-by-Step Credential Configuration

How to obtain and configure every credential the app **requires at boot** in
production. Companion to `DEPLOYMENT.md` (which covers the Fly.io mechanics).
Work through each section, collect the values, then set them all in one
`fly secrets set` at the end.

> ⏱️ **Start with section 4 (WhatsApp) first** — Meta template approval takes
> 1–3 business days. Everything else is same-day.

---

## 1. Paystack (card + mobile-money payments)

Test keys are fine for a smoke deploy; swap to live keys before real customers.

1. Create an account at <https://dashboard.paystack.com/signup> (choose
   **Ghana** as country — enables GHS + MTN MoMo/Vodafone Cash channels).
2. For **test keys**: Dashboard → **Settings → API Keys & Webhooks**. Copy:
   - `Secret key` (starts `sk_test_…`) → `PAYSTACK_SECRET_KEY`
   - `Public key` (starts `pk_test_…`) → `PAYSTACK_PUBLIC_KEY`
3. For **live keys**: complete business verification (Compliance tab —
   business registration docs, bank account) first; live keys appear on the
   same page (`sk_live_…` / `pk_live_…`).
4. **Webhook URL** (same Settings page): set to
   `https://<your-app>.fly.dev/webhooks/paystack`
   — the endpoint verifies Paystack's HMAC-SHA512 signature with your secret
   key, so no extra webhook secret is needed.
5. To enable mobile-money channels on test mode: **Settings → Preferences →
   Payment Channels** → tick Mobile Money.

## 2. Resend (transactional email)

The app **raises at boot** without `RESEND_API_KEY`.

1. Sign up at <https://resend.com/signup>.
2. **Domain** (required for real delivery): Resend → **Domains → Add Domain**
   → enter your sending domain (e.g. `emakola.com`) → add the 3 DNS records
   (SPF/DKIM/MX) at your DNS host → wait for "Verified".
   *Smoke-deploy shortcut:* skip domain setup and use Resend's sandbox —
   emails deliver only to your own signup address.
3. **API key**: Resend → **API Keys → Create API Key** → name `emakola-prod`,
   permission **Sending access**, domain: your domain (or All).
   Copy the `re_…` value → `RESEND_API_KEY`. It is shown **once**.

## 3. SMS gateway (Arkesel — or any compatible HTTP gateway)

The app posts JSON to `SMS_API_URL` with a Bearer `SMS_API_KEY` and sender
`SMS_SENDER_ID`. All three **raise at boot** if missing. For Ghana, Arkesel
is the usual choice:

1. Sign up at <https://sms.arkesel.com> → verify your business.
2. **Sender ID**: dashboard → **Sender IDs → Request Sender ID** → request
   `Emakola` (max 11 chars, no spaces). NCA approval usually < 1 day.
   → `SMS_SENDER_ID=Emakola`
3. **API key**: dashboard → **Settings → API Keys** → generate.
   → `SMS_API_KEY`
4. **API URL** → `SMS_API_URL=https://sms.arkesel.com/api/v2/sms/send`
5. Top up SMS credits (pay-as-you-go) — sends fail with insufficient balance.
6. **Compatibility check**: `Emakola.Notifications.Channels.SMS` sends
   `{"to": …, "message": …, "sender": …}` with `Authorization: Bearer <key>`.
   If your gateway's contract differs (Arkesel v2 uses an `api-key` header),
   adapt `lib/emakola/notifications/channels/sms.ex` — run one real test
   send before launch (see Verification below).

## 4. WhatsApp Business API (Meta Cloud API) — START FIRST

Token + phone-number ID **raise at boot**. Templates need Meta approval
(1–3 days), and **the template names + parameter order are a hard contract
with the code** (`Emakola.Notifications.Channels.WhatsApp`).

### 4a. Accounts & phone number

1. Create a **Meta Business Portfolio** at <https://business.facebook.com>.
2. Go to <https://developers.facebook.com> → **My Apps → Create App** →
   type **Business** → add the **WhatsApp** product.
3. In WhatsApp → **API Setup**: add/verify a real phone number (it cannot be
   an active personal WhatsApp number). Note the **Phone number ID**
   (a long numeric ID, *not* the phone number) → `WHATSAPP_PHONE_NUMBER_ID`.

### 4b. Permanent access token

The API Setup page's temporary token expires in 24 h — don't ship it.

1. <https://business.facebook.com/settings> → **Users → System Users** →
   **Add** → name `emakola-server`, role Admin.
2. **Add Assets** → your WhatsApp app → full control.
3. **Generate New Token** → select the app → permissions:
   `whatsapp_business_messaging`, `whatsapp_business_management` →
   expiration **Never** → copy → `WHATSAPP_API_TOKEN`.

### 4c. Register the message templates (the hard contract)

Meta Business → **WhatsApp Manager → Message Templates → Create Template**,
category **Utility**, language **English**. Create all six, with EXACTLY
these names and numbered placeholders in this order:

| Template name | {{1}} | {{2}} | {{3}} | {{4}} |
|---|---|---|---|---|
| `order_placed` | order number | store name | total | currency |
| `order_confirmed` | order number | store name | total | currency |
| `order_shipped` | order number | store name | total | currency |
| `order_delivered` | order number | store name | total | currency |
| `order_cancelled` | order number | store name | total | currency |
| `supplier_fulfillment` | order number | supplier name | items list | ship-to address |

Suggested bodies (edit tone freely — placeholder ORDER may not change):

- `order_placed`: *“Your order {{1}} at {{2}} has been received. Total: {{4}} {{3}}. We'll confirm shortly.”*
- `order_confirmed`: *“Order {{1}} at {{2}} is confirmed — payment of {{4}} {{3}} received. We're preparing it now.”*
- `order_shipped`: *“Good news! Order {{1}} from {{2}} ({{4}} {{3}}) is on its way.”*
- `order_delivered`: *“Order {{1}} from {{2}} has been delivered. Thank you for shopping with us!”*
- `order_cancelled`: *“Order {{1}} at {{2}} ({{4}} {{3}}) has been cancelled. Contact us with any questions.”*
- `supplier_fulfillment`: *“New order {{1}} for {{2}}. Items: {{3}}. Ship to: {{4}}. Please confirm and share a tracking number.”*

Submit each for review; status must be **Approved** before sends work.
Until then, WhatsApp sends fail (Oban retries 3×, then discards) — SMS and
email still go out, so this degrades gracefully.

## 5. Generated secrets (no signup — just generate)

From the project root:

```bash
mix phx.gen.secret        # → SECRET_KEY_BASE  (≥64 chars; cookies/sessions)
mix phx.gen.secret 64     # → TOKEN_SIGNING_SECRET  (auth-token signing)
```

Generate each **once**, store in your password manager. Rotating
`SECRET_KEY_BASE` invalidates sessions; rotating `TOKEN_SIGNING_SECRET`
invalidates every login token.

## 6. Set everything (one command, run it yourself)

With all values collected (Tigris `AWS_*` vars are auto-set by
`fly storage create`; `DATABASE_URL` by `fly postgres attach`):

```bash
fly secrets set \
  SECRET_KEY_BASE="<from mix phx.gen.secret>" \
  TOKEN_SIGNING_SECRET="<from mix phx.gen.secret 64>" \
  DATABASE_SSL="false" \
  RESEND_API_KEY="re_..." \
  PAYSTACK_SECRET_KEY="sk_test_..." \
  PAYSTACK_PUBLIC_KEY="pk_test_..." \
  SMS_API_KEY="..." \
  SMS_SENDER_ID="Emakola" \
  SMS_API_URL="https://sms.arkesel.com/api/v2/sms/send" \
  WHATSAPP_API_TOKEN="EAAG..." \
  WHATSAPP_PHONE_NUMBER_ID="123456789012345" \
  --app <your-app>
```

Optional extras: `HUBTEL_CLIENT_ID`/`HUBTEL_CLIENT_SECRET`/`HUBTEL_WEBHOOK_ALLOWLIST`
(second payment gateway), `DEMO_MODE=true`, `DNS_CLUSTER_QUERY` (set in fly.toml).

## 7. Verification after `fly deploy`

```bash
curl https://<your-app>.fly.dev/api/health        # {"status":"ok"} — DB reachable
fly logs                                          # no boot raises, Oban started
```

Then end-to-end: register a merchant → onboard → place a **test order**
(Paystack test card `4084 0840 8408 4081`, any future expiry, CVV `408`) →
confirm you receive the order SMS + email; check WhatsApp once templates are
approved; upload a product image (proves Tigris/S3).

## Quick checklist

- [ ] WhatsApp templates submitted (day 1 — approval lag)
- [ ] Paystack account + test keys + webhook URL
- [ ] Resend key (+ domain verified for real delivery)
- [ ] SMS sender ID approved + API key + credits
- [ ] WhatsApp permanent token + phone number ID
- [ ] SECRET_KEY_BASE / TOKEN_SIGNING_SECRET generated & stored
- [ ] `fly secrets set` run (section 6)
- [ ] `fly deploy` + health check + test order
