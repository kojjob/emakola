# Post-Keys Validation — LAUNCH_TODO §8 + §9, in minutes

Run this the moment real provider keys are set (`LAUNCH_TODO` §6). It
interleaves the browser steps only a human can do with the script that
verifies each one actually worked underneath:

```bash
scripts/post_keys_validation.sh   # each step below names its subcommand
```

Everything the script does is **read-only**. Use Paystack **test keys** for
the first full pass (test card works, no real money), then repeat the payment
leg once on live keys with a real GHS 1 MoMo charge.

---

## Stage 0 — Preflight (script only, ~30s)

```bash
scripts/post_keys_validation.sh preflight
```

Pass looks like: every secret `LIVE` (or `TEST MODE` for the rehearsal pass,
never `DUMMY`/`UNSET`), site + health 200, **unsigned webhook POST → 401**
(route live, signature enforced). The wss check is best-effort from curl —
101 is a definitive pass; anything else is settled in Stage 1, because
onboarding is a LiveView (broken socket = forms don't submit; definitive:
browser DevTools → Network → WS → `/live/websocket` → Status 101).

Also confirm in the Paystack dashboard: webhook URL is
`https://makola.io/webhooks/paystack`, Mobile Money channel enabled.

## Stage 1 — Merchant signup + storefront (browser)

1. Register a fresh merchant at `/auth/register`, onboard a test store,
   upload one product image (proves Tigris), publish one product.
2. Open the storefront on a phone-sized window; add to cart.

No script step — failure is visible.

## Stage 2 — Un-split test order (browser + script)

With **no payout details saved yet**, place an order and pay with the
Paystack test card `4084 0840 8408 4081` (any future expiry, any CVV).

- [ ] Order confirmation page reached
- [ ] Order SMS arrives (Arkesel credits + sender ID working)
- [ ] Order email arrives (Resend domain verified — sandbox only mails yourself)

```bash
scripts/post_keys_validation.sh payment <REFERENCE>   # from the order/dashboard
```

Pass: `status=success split_mode=none`, no splits — the charge sits in the
platform account as payout backlog. That is correct for a store with no
verified subaccount.

## Stage 3 — Revenue rails: subaccount (browser + script)

In `/admin/payouts`, save MoMo payout details for the test store
(**MTN or Telecel or AirtelTigo** — stored provider values are `mtn` /
`vodafone` / `airteltigo`; the `vodafone` value is Paystack's `VOD` code for
Telecel, do not "fix" it).

```bash
scripts/post_keys_validation.sh subaccount <store-slug>
```

Pass: `subaccount=ACCT_... verification=verified` (the
`SubaccountCreationWorker` runs async — give it ~a minute).

## Stage 4 — Revenue rails: split order (browser + script)

Place a **second** test order on the same store.

```bash
scripts/post_keys_validation.sh payment <REFERENCE_2>
```

Pass: `split_mode=platform_fee`, TWO splits — `merchant` (settled, 98%) and
`platform` (settled, the 2% fee). This is the platform's first earned pesewa.

```bash
scripts/post_keys_validation.sh finance
```

Pass: platform fees > 0.

## Stage 5 — Payout execution (browser + script)

On `/platform/finance`, the FIRST order's balance shows as outstanding for
the store. Click **Pay out** (gated `:manage_billing`, audit-logged).

```bash
scripts/post_keys_validation.sh payouts <store-slug>
```

Pass: a payout `processing` → (after the `transfer.success` webhook) `paid`,
and `outstanding backlog: 0`.

⚠️ Paystack **holds a new subaccount's first payout** until it is verified in
their dashboard — a `processing` payout that does not flip within the hour is
usually this, not a bug.

## Stage 6 — WhatsApp (once Meta approves the templates)

Trigger one order notification with `WHATSAPP_*` set; check delivery on a
real number. Independent of everything above — do not block launch on it.

---

**Cleanup:** the test store created in Stage 1 can be purged afterwards with
`Emakola.Stores.DemoPurge` (preview → execute), same tool used for the seeded
demo data.
