# Launch Timetable — 2-Week Sprint to Live

> **Goal:** real paying merchants transacting by **Fri 2026-07-10**.
> **Pace:** full-time (~40 hrs/wk). **Priority:** launch-first / revenue.
> **Source of truth:** `checklist.md` (master) · `LAUNCH_TODO.md` (ordered setups) ·
> `docs/PROVIDER_SETUP.md` (credential how-tos, §refs below point here).
> Created 2026-06-26.

## Critical-path risk (read first)

Everything in **your** control fits the 2 weeks. The one thing that can slip the
date is **Paystack LIVE keys**, which require business verification (days,
external). Mitigation: run the whole sprint on Paystack **test** keys, soft-launch
in test mode, and hot-swap live keys via `fly secrets set` the hour they clear.

## How to read this

- Every code task runs inside the **§3 quality gates + §4 deploy runbook** from
  `checklist.md` (TDD → `mix test` → `mix format` → `mix credo --strict` →
  fresh-compile → CI green on `main` before `fly deploy`). Those wrap each task;
  they are not separate line items.
- 🔌 external/ops (no code) · 💻 code · ⏳ has an external wait → **start early**.

---

## Day 0 — TODAY (Fri 2026-06-26, ≈3 hrs): fire the long-lead clocks

Do these first; they wait on other people and tick over the weekend.

- [ ] ⏳🔌 Submit the **6 WhatsApp templates** to Meta (1–3 day approval, gates nothing) — `PROVIDER_SETUP.md` §4c
- [ ] ⏳🔌 Request **Arkesel Sender ID `Emakola`** (NCA approval <1 day) — §3
- [ ] ⏳🔌 Create **Paystack** account (country: **Ghana**) and **start business verification** for live keys (the long pole) — §1
- [ ] ⏳🔌 **Resend**: create account, add the sending domain + DNS records (let propagation run over the weekend) — §2
- [ ] 🔌 **GitHub branch protection**: Settings → Branches → `main` → ☑ *Require branches up to date* (5 min; kills the stranded-PR class) — `LAUNCH_TODO.md`
- [ ] ⏳🔌 *(optional)* Create the **Firebase** project + service-account key (pushes FCM Stage A forward) — `LAUNCH_TODO.md` (Mobile push)

---

## Week 1 — Launch execution (Mon Jun 29 – Fri Jul 3)

### Mon Jun 29 — wire the gateways (test tier)
- [ ] 🔌 Paystack: test keys → webhook `https://emakola.fly.dev/webhooks/paystack` → enable **Mobile Money** channel — §1
- [ ] 🔌 Resend: API key; confirm the domain reads **Verified** (DNS from Friday) — §2
- [ ] 💻 Arkesel: API key + top up → **one real test send**. If it 401s, switch `lib/emakola/notifications/channels/sms.ex` from `Authorization: Bearer` to the `api-key` header (LAUNCH_TODO item 4 flags this) — TDD the change
- [ ] 🔌 WhatsApp: mint the **permanent System User token** + Phone Number ID (NOT the 24 h API-Setup token) — §4a–4b

### Tue Jun 30 — flip prod onto real keys + stand up monitoring access
- [ ] 🔌 `fly secrets set RESEND_API_KEY=… PAYSTACK_SECRET_KEY=… PAYSTACK_PUBLIC_KEY=… SMS_API_KEY=… WHATSAPP_API_TOKEN=… WHATSAPP_PHONE_NUMBER_ID=… --app emakola` — §7
- [ ] 💻🔌 Bootstrap the prod **platform owner** so you can monitor app + users:
      `fly ssh console` → `/app/bin/emakola rpc 'Emakola.Release.bootstrap_platform_owner("you@example.com")'`
      → sign in at `/platform/login` → complete forced-TOTP → `/platform`
- [ ] 🔌 Store-data decision — recommend **organic**: register your first real store at `/auth/register` (skip the `Password123!` seed for a real launch) — LAUNCH_TODO item 7

### Wed Jul 1 — smoke-test the whole funnel (§8)
- [ ] 🔌 `/api/health` → register → onboard → **test order** (Paystack test card `4084 0840 8408 4081`) → order **SMS + email** arrive → upload a product image (proves Tigris) → WhatsApp send once Meta approves
- [ ] 💻 Fix whatever the smoke test surfaces (budget the day for breakage)

### Thu Jul 2 — verify the revenue rails (§9 — the Phase-0 success metric)
- [ ] 🔌 `/admin/payouts`: **save MoMo payout details first** → `SubaccountCreationWorker` creates the verified Paystack subaccount
- [ ] 🔌 Place a normal order → confirm the **split** (merchant net to subaccount, **2%** platform fee kept). No subaccount ⇒ falls back to `:none` (100% held)
- [ ] 🔌 `/platform/finance`: approve a payout → confirm the Paystack **Transfer** fires (⚠️ first payout held until the subaccount is verified in Paystack's dashboard)
- [ ] 💻 Verify `conn.remote_ip` is the **real client IP** behind the Fly proxy (mobile sign-in rate limit keys on it) — LAUNCH_TODO
- [ ] 🔌 Click the **PDF export** once in prod (ChromicPDF is excluded from CI)

### Fri Jul 3 — custom domain + error monitoring
- [ ] ⏳🔌 Cloudflare DNS: A/AAAA + `www` + `*` wildcard (**DNS-only/grey** first) → `fly certs add emakola.com` + `'*.emakola.com'` → wait **Ready** → `fly secrets set PHX_HOST=emakola.com` — §9
- [ ] 💻 Wire **Sentry** (the Sentry plugin is already connected — use the `sentry-sdk-setup` skill) for error/perf visibility before traffic
- [ ] 🔌 Buffer: complete any WhatsApp template approvals that landed; re-run the WhatsApp leg of the smoke test

> **End of Week 1:** live on real keys · owner account monitoring · domain cert
> provisioning · revenue split proven in test.

---

## Week 2 — Harden before real customers, then go live (Mon Jul 6 – Fri Jul 10)

### Mon Jul 6 — correctness pass (before real customers)
- [ ] 💻 Catalog default `:read` → add `status == :published` filter (TDD) — `checklist.md` §5b (the open correctness survivor; stops unpublished products leaking on the storefront)
- [ ] 💻 Quick follow-ups: host guard on the apex `/sitemap.xml` route (`router.ex` TODO) · single `data-reveal` per section · `.reveal-hidden` reduced-motion override

### Tue Jul 7 — perf + a11y polish
- [ ] 💻 Convert the mobile-menu toggle to `Phoenix.LiveView.JS` (kills the per-tap server round-trip)
- [ ] 💻 Digested (`~p`) paths for hero/CTA background images
- [ ] 💻 `sameAs` social links in Organization JSON-LD (once footer socials are real)

### Wed Jul 8 — post-launch SEO (needs the live domain)
- [ ] 🔌 Submit sitemap to **Google Search Console + Bing Webmaster Tools** — §6
- [ ] 🔌 Rich Results Test (FAQPage/Offer) · Core Web Vitals on the live domain (hero LCP, zero CLS)
- [ ] 🔌 Replace illustrative store-wall content with the first real store · correct the "500+ merchants" stat

### Thu Jul 9 — go-live readiness
- [ ] ⏳🔌 Swap Paystack **live** keys once business verification clears (same `fly secrets set`) — the one item that can slip the date; soft-launch in test mode meanwhile
- [ ] 🔌 Purge/rotate demo creds (if seeded) · rotate Postgres creds if transcripts were shared
- [ ] 💻 FCM **Stage A**: `iex -S mix` → `Goth.fetch(Emakola.Goth)` → `{:ok, %Goth.Token{}}` (verifies the credential; Stage B waits on the Flutter app)
- [ ] 🔌 Final full smoke test on the **live domain** with live keys

### Fri Jul 10 — LAUNCH + watch
- [ ] 🔌 Onboard the first real merchant(s) · place a real order
- [ ] 🔌 Monitor: Sentry + `fly logs --app emakola` + Postgres memory headroom (1 GB — don't scale app machines past the DB's connection budget) — §6
- [ ] Hold the day for incident response

> **Target: live with real paying merchants, EOD Fri 2026-07-10.**

---

## Phase 3 — Engineering backlog (Week of Jul 13+, post-launch)

Real work, but explicitly **not** launch-blockers, and the refactors alone are
>1 week — do not let them block the launch. Sequenced after you're live and stable.

**Refactors (over the 200-line guideline)**
- [ ] `landing_live.ex` (680) → dead `Phoenix.Component`
- [ ] `product_live/index.ex` (1337) + `app.html.heex` (901) — finish extraction
- [ ] Replace ~1968 inline `bg-[#…]` literals with named tokens; resolve `#B45309`/`#CA8A04` drift; unify `stat_card`/`kpi_card`

**Architecture**
- [ ] Regenerate Ash resource snapshots (one deliberate `mix ash.codegen` session) — unblocks generated migrations
- [ ] Promote `Emakola.Inventory` to a real Ash domain (multi-location)
- [ ] Extract remaining inline Ash anon fns (Order number, status `after_action`)
- [ ] Decommission the legacy User/Organisation auth path (`resolve_user`'s `current_store: nil` trap)

**CI / cleanup**
- [ ] `mix dialyzer` in CI · create `.sobelow-conf` · split deps/_build cache keys · ratchet coverage 55→90 · collapse the duplicate SMS hierarchy · fix `RawBodyReader`'s Stripe moduledoc

**Feature gaps**
- [ ] Weight/tiered delivery fees · WhatsApp low-stock channel · Hubtel auto-refund
- [ ] Low-stock duplicate-alert race (concurrent checkouts double-send)
- [ ] Seed digital-downloads demo data · design-system sub-project 3 (DesignTokens/FontLoader across 14 themes)

**Larger initiatives (own planning, gated)**
- [ ] White-label Phase 2 section editor (Shopify-style) — not started
- [ ] FCM **Stage B** + iOS APNs `.p8` — gated on the Phase 1 Flutter client
- [ ] Hubtel optional second gateway (`HUBTEL_CLIENT_ID/SECRET/WEBHOOK_ALLOWLIST` together, or none)

---

## Lead-time map (why the order is what it is)

| Item | Wait | Owner | Fired | Used |
|---|---|---|---|---|
| WhatsApp templates | 1–3 days | Meta | Fri Jun 26 | Wed–Fri smoke |
| Arkesel Sender ID | <1 day | NCA | Fri Jun 26 | Mon Jun 29 |
| Resend domain | hours (DNS) | you | Fri Jun 26 | Mon Jun 29 |
| Paystack **test** keys | instant | you | Mon Jun 29 | Mon Jun 29 |
| Paystack **live** keys | **days (verification)** | Paystack | Fri Jun 26 | Thu Jul 9 ⚠️ |
| Domain certs | mins–hours | Fly | Fri Jul 3 | Fri Jul 3 |
| FCM Stage B | — | Flutter app | — | Phase 1 |
