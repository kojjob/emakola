# LAUNCH TODO — Setups Between Here and a Real Launch

> **State (2026-06-11):** https://emakola.fly.dev is **LIVE** — London region,
> ~50ms, healthy, migrations run — on **dummy provider keys** with an **empty
> database**. This file tracks every remaining setup, in order.
> How-tos: `docs/PROVIDER_SETUP.md` (credentials, illustrated) ·
> `docs/DEPLOYMENT.md` (infra mechanics).

---

## 🚀 Launch-critical — do in this order

- [ ] **1. Submit the 6 WhatsApp templates to Meta TODAY** — approval takes
      1–3 days and gates nothing else, so start it first. Exact names,
      `{{n}}` parameter order, and copy-paste bodies: `PROVIDER_SETUP.md` §4c.
- [ ] **2. Paystack** — account (country: **Ghana**) → test keys → webhook URL
      `https://emakola.fly.dev/webhooks/paystack` → enable the Mobile Money
      channel. (§1)
- [ ] **3. Resend** — API key; add + DNS-verify the sending domain for real
      delivery (sandbox only mails yourself). (§2)
- [ ] **4. Arkesel SMS** — request Sender ID `Emakola` (NCA approval <1 day)
      → API key → top up credits. ⚠️ Then ONE real test send: our channel
      sends `Authorization: Bearer`; Arkesel v2 may expect an `api-key`
      header — adapt `lib/emakola/notifications/channels/sms.ex` if so. (§3)
- [ ] **5. WhatsApp credentials** — permanent **System User** token (the
      API-Setup page token expires in 24 h — don't ship it) + Phone Number ID.
      (§4a–4b)
- [ ] **6. Replace the dummy secrets** — one command with real values
      (template in `PROVIDER_SETUP.md` §7):
      `fly secrets set RESEND_API_KEY=… PAYSTACK_SECRET_KEY=… PAYSTACK_PUBLIC_KEY=… SMS_API_KEY=… WHATSAPP_API_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=… --app emakola`
- [ ] **7. Decide store data: seed vs organic** —
      **seed**: 3 demo stores incl. the dropshipping showcase (⚠️ fixed
      password `Password123!` — must be removed/changed before real
      customers) · **organic**: register at `/auth/register` and build the
      first store by hand.
- [ ] **8. Smoke test with real keys** (`PROVIDER_SETUP.md` §8) —
      `/api/health` → register → onboard → test order (Paystack test card
      `4084 0840 8408 4081`) → order SMS + email arrive → product image
      upload (proves Tigris) → WhatsApp send once Meta approves.

## 🌐 Before opening to the public

- [ ] **Custom domain** — Cloudflare DNS (A/AAAA + `www` + `*` wildcard for
      merchant subdomains; **DNS-only/grey cloud first**) → `fly certs add
      emakola.com` and `'*.emakola.com'` → wait for **Ready** →
      `fly secrets set PHX_HOST=emakola.com` → optionally flip Cloudflare to
      Proxied. (§9)
- [ ] **Paystack live keys** — after business verification; swap with the
      same `fly secrets set`.
- [ ] **Purge demo credentials** — if step 7 seeded, delete or re-password
      the `Password123!` demo accounts.
- [ ] **Rotate Postgres credentials** — `fly postgres attach` echoes the DB
      password into terminal output; rotate if those transcripts are ever
      shared.
- [ ] **GitHub branch protection** — repo Settings → Branches → `main` →
      ☑ *Require branches to be up to date before merging*. Five separate
      stranded-PR/semantic-merge incidents this cycle; one checkbox kills
      the whole class.
- [ ] **Click the PDF export once in prod** — ChromicPDF/Chromium ships in
      the image (on-demand spawn) but the `:pdf` tests are excluded from CI;
      verify the real button works.
- [ ] **Hubtel (optional second gateway)** — set `HUBTEL_CLIENT_ID`,
      `HUBTEL_CLIENT_SECRET` **and** `HUBTEL_WEBHOOK_ALLOWLIST` together
      (the webhook is IP-allowlisted and fails closed) — or leave all unset.
- [ ] **Monitoring** — nothing is wired (Sentry in old docs is not a
      dependency). Until something is chosen, `fly logs` is the only window;
      pick Sentry/AppSignal once real traffic starts.

## 🧰 Engineering backlog (post-launch, rough priority)

- [ ] **Regenerate Ash resource snapshots** — `mix ash.codegen` is unusable
      (stale `priv/resource_snapshots/`); every migration is hand-written
      until one deliberate regeneration session fixes it.
- [ ] **Decommission the legacy User/Organisation auth path** — dead since
      the registration fix (#108); `resolve_user`'s `current_store: nil`
      stub is a trap.
- [ ] **Cart re-architecture before scaling past 1 machine** — carts are
      node-local ETS; >1 machine needs sticky sessions or a shared store.
      (BEAM clustering itself is already wired.)
- [ ] **Design system sub-project 3** — DesignTokens/FontLoader across all
      14 themes; remaining ~17 admin pages join the consistency-test
      `@swept` list opportunistically.
- [ ] **Seed digital-downloads demo data** — feature works but has no demo
      data (same invisibility dropshipping had pre-Tiny-Stitches).
- [ ] **Low-stock duplicate-alert race** — pre-existing; concurrent
      checkouts can double-send the low-stock SMS.
- [ ] **Stripe merchant billing** — dormant scaffolding today (no SDK, no
      webhook route, no env reads — deliberately NOT in the setup guide).
      When subscription billing becomes a real feature: SDK + route +
      `STRIPE_*` secrets + its own PROVIDER_SETUP section.
- [ ] **Refresh `TODO.md`** — the April-25 dev backlog predates this cycle;
      re-audit it (many entries are already done: WhatsApp/SMS integration,
      admin component extraction, named tokens, domain restructuring, …).
