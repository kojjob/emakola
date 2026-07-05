# Emakola — Master Reference Checklist

> One page to rule the others. Current state, recurring quality gates, the deploy
> runbook, and every known follow-up — with pointers into the deeper docs instead
> of duplicating them.
>
> **Deeper docs:** `LAUNCH_TODO.md` (launch-critical setups, in order) ·
> `TODO.md` (**engineering backlog of record** — re-audited 2026-06-25) ·
> `docs/PROVIDER_SETUP.md` (illustrated credential guide) ·
> `docs/DEPLOYMENT.md` (infra mechanics) · `docs/ACTION_ROADMAP.md` (forward
> product plan) · `docs/superpowers/specs/` + `docs/superpowers/plans/`
> (feature design history).
>
> **Superseded** (don't track work here): `docs/REMAINING-AREAS-2026-04-26.md`
> (folded into the re-audited `TODO.md`) · `docs/ROADMAP.md` (historical Phase-1
> record; forward plan now lives in `docs/ACTION_ROADMAP.md`).
>
> Last updated: 2026-06-25.

---

## 1. Where we are (state snapshot)

- [x] **Production is LIVE** — https://emakola.fly.dev (Fly app `emakola`, London/lhr,
      2× shared-cpu machines, `auto_stop = suspend`, Postgres `emakola-db-lhr` 1GB,
      Tigris bucket `emakola-uploads`)
- [x] **Landing redesign deployed** (PR #126) — merchant-first hero with rotating
      headline, store wall (6 trade verticals), feature stories, photo-led features
      grid incl. dropshipping, "Launch before lunch" step cards, FAQ, final CTA
- [x] **`/pricing` page** with shared marketing nav + Offer JSON-LD
- [x] **SEO/AI-SEO foundation** — JSON-LD `@graph` (Organization, WebSite,
      SoftwareApplication, FAQPage), canonical URLs, platform `/sitemap.xml`,
      robots.txt sitemap line, FAQPage copy written to be quotable
- [x] **Platform admin auth** (PR #127) — owner bootstrap + TOTP-reset mix tasks
- [x] **Postgres-backed carts** (PR #124) — horizontal scaling unblocked
- [ ] **Real provider keys** — Paystack, Resend, Arkesel SMS, WhatsApp are still
      **dummy placeholders**; payments and notifications are inert →
      `LAUNCH_TODO.md` items 1–6
- [ ] **Store data decision** — production DB is empty (seed vs organic) →
      `LAUNCH_TODO.md` item 7
- [ ] **Custom domain** — `emakola.com` DNS does not point at the app yet; the
      sitemap/canonical URLs already use it as the canonical host →
      `PROVIDER_SETUP.md` §9

## 2. Launch-critical (summary — full detail in `LAUNCH_TODO.md`)

- [ ] WhatsApp templates submitted to Meta (1–3 day approval — start first)
- [ ] Paystack account + test keys + webhook + Mobile Money channel
- [ ] Resend API key + DNS-verified sending domain
- [ ] Arkesel Sender ID `Emakola` + API key + auth-header verification
- [ ] WhatsApp permanent System User token + Phone Number ID
- [ ] `fly secrets set …` with all real values (one command, §7)
- [ ] Seed-vs-organic store data (⚠️ seed uses fixed `Password123!` — remove before real customers)
- [ ] End-to-end smoke test with real keys (§8)
- [ ] `emakola.com` DNS → Fly + certificates; then submit sitemap to Google
      Search Console & Bing Webmaster Tools

## 3. Every-change quality gates (the recurring loop)

**Before every commit:**
- [ ] TDD — failing test first, then implementation (no exceptions)
- [ ] `mix test <scoped files>` green
- [ ] `mix format` (CI runs `--check-formatted`)
- [ ] `mix credo --strict` clean
- [ ] No `IO.inspect`/`dbg`, no secrets in code
- [ ] Money only as integer minor units (pesewas/kobo) — never floats
- [ ] Tenant-scoped queries carry `store_id` context — no cross-store leaks

**Before every PR:**
- [ ] Branch from `main` (`feature/…`, `fix/…`, `docs/…`); **PRs target `main`**
      (the `develop` branch is dead — ~700 commits stale; ignore CLAUDE.md's
      develop line)
- [ ] Fresh-compile check: `mix clean --only app && mix test --warnings-as-errors`
      (cached `_build` hides warnings CI will catch)
- [ ] CI is the source of truth for the full suite. If the local full suite
      mass-fails in areas you didn't touch (auth/admin/accounts), suspect your
      local environment first — check test-DB migrations and service stubs —
      and trust CI before declaring a baseline or a regression
- [ ] Conventional commit messages; atomic commits

**Frontend specifics (hard-won, see also project CLAUDE.md):**
- [ ] Custom CSS only inside `@layer components` (unlayered CSS outranks Tailwind utilities in v4)
- [ ] Client UI state via `Phoenix.LiveView.JS` or pure CSS animation — never
      CSS-checkbox toggles (LiveView diffs lose `:checked`)
- [ ] Keyframe animations: omit `transform` from the final keyframe when the
      element also has hover transforms — `fill-mode` would pin it
      (see `feature-rise` in `app.css`)
- [ ] Tailwind v4: `rotate-*`/`translate-*` are standalone CSS properties, not
      `transform` — measure `getComputedStyle(el).translate` when verifying
- [ ] Dynamic class names must be full literal strings (Tailwind scanner can't
      see interpolation)
- [ ] Images: download at rendered crop size, honest `width`/`height` attrs,
      `loading="lazy"` below the fold, hero preloaded via the `preload_image` assign
- [ ] Low-literacy audience: communicate by photo + one fixed color per concept +
      1–2 word labels; icons `aria-hidden`, real meaning carried by text/alt
- [ ] Reduced-motion fallback for every animation
- [ ] **Browser-verifying CSS in dev: unregister the PWA service worker first**
      (it serves `app.css` cache-first; DevTools → Application → Service Workers)
- [ ] Stop `mix phx.server` during heavy edits (hot-reload races; stale watcher builds)

## 4. Deploy runbook (what "ship it" means here)

1. [ ] PR merged to `main` and **CI green on `main` itself** (`gh run list --branch main`)
2. [ ] Local checkout of the exact commit: `git fetch && git checkout --detach origin/main`
       (works even when another worktree holds the `main` branch)
3. [ ] Working tree clean — untracked files leak into the Docker build context
4. [ ] `fly deploy --app emakola` — release command runs migrations automatically
5. [ ] Watch both machines reach the new version with passing checks
       (`fly status --app emakola`)
6. [ ] Verify live content (not just health): `curl -s https://emakola.fly.dev/ |
       grep "<expected new copy>"` + spot-check `/pricing`, `/sitemap.xml`
7. [ ] Remember: a deploy invalidates sessions once (token signing) — harmless
       until there are real users; coordinate when there are
8. [ ] Rollback if needed: `fly releases --app emakola` → `fly deploy --image <previous>`

## 5. Known follow-ups (accumulated from reviews — none blocking)

- [ ] Convert the mobile-menu toggle to `Phoenix.LiveView.JS` (currently a server
      round-trip per tap; pattern predates the redesign)
- [ ] Digested (`~p`) paths for hero/CTA background images (far-future caching on
      the heaviest assets)
- [ ] `sameAs` social links in Organization JSON-LD once footer socials are real
      (currently `href="#"` placeholders)
- [ ] Host guard on the apex `/sitemap.xml` route when store subdomain routing
      lands (TODO comment in `router.ex`)
- [ ] Single `data-reveal` per section (section + grid currently both reveal —
      doubled perceived motion)
- [ ] `cta-market.jpg` is used twice on the landing page (Many stores card +
      final CTA) — swap one when a better photo turns up
- [ ] Update CLAUDE.md's "PR targeting develop" line (confirmed stale; Kojo
      deferred the edit)
- [ ] `.reveal-hidden` base transition has no `prefers-reduced-motion` override
      (pre-existing, app-wide)
- [ ] Replace the test-env drift on this machine (local full suite fails in
      auth/admin areas that CI passes — env-only, but worth fixing for local
      confidence)

## 5b. Engineering backlog (re-audited 2026-06-25 — detail in `TODO.md`)

> The April backlog was re-verified against current code: 31 items were already
> DONE, 15 partial, 12 open. Full evidence + file:line refs in `TODO.md`. The
> survivors, by cluster:

**Security & correctness (do first)**
- [x] Audit silent `rescue _ -> []` blocks — DONE 2026-06-25 (48 data-load
      rescues now log; ~11 benign left as-is)
- [x] Consolidate the two divergent Paystack webhook code paths — DONE
      2026-06-25 (removed dead synchronous `PaystackWebhook`; Oban worker is sole authority)
- [x] `bypass action_type(:create)` tightened across tenant resources — DONE
      2026-06-25: Store via #217 (Merchant-only `:create`); Order/Customer/LineItem
      reviewed and already hardened (same forbid pattern; creates use `authorize?: false`).
- [ ] Catalog default `:read` lacks a `status == :published` filter (low risk)
- [x] CSP `style-src 'unsafe-inline'` (P2) — DONE 2026-06-25 as documented
      accepted risk (~760 un-nonceable style attrs; script-src already nonce-only;
      split into -attr/-elem with rationale in the plug; future = nonce the ~32 `<style>` blocks)

**Refactor (still over the 200-line guideline)**
- [ ] `landing_live.ex` (680) → dead `Phoenix.Component`
- [ ] `product_live/index.ex` (1337) & `app.html.heex` (901) — finish extraction
- [ ] Replace ~1968 inline `bg-[#…]` literals with named tokens; resolve the
      `#B45309`/`#CA8A04` color drift; unify `stat_card`/`kpi_card`

**Feature gaps (partial)**
- [ ] Wire a real SMS provider (Arkesel/Hubtel — overlaps launch item 4)
- [ ] Weight/tiered delivery fees; WhatsApp low-stock channel; Hubtel auto-refund

**Architecture**
- [ ] Promote `Emakola.Inventory` to a real Ash domain (multi-location)
- [ ] Extract remaining inline Ash anon fns (Order number, status `after_action`)

**White-label**
- [ ] Phase 2 section editor (Shopify-style) — not started

**CI / cleanup**
- [ ] Add `mix dialyzer` to CI · create `.sobelow-conf` · split deps/_build
      cache keys · ratchet coverage 55→90 · collapse the duplicate SMS hierarchy
      · fix `RawBodyReader`'s Stripe moduledoc

## 6. Post-launch (once real keys + domain are in)

- [ ] Submit sitemap to Google Search Console + Bing; verify FAQPage/Offer rich
      results with Google's Rich Results Test
- [ ] Re-run Core Web Vitals on the live domain (hero LCP, zero CLS)
- [ ] Replace illustrative store-wall content with real merchant stores +
      consent-cleared photos when available
- [ ] Update the "500+ merchants" stat the moment a real number exists
- [ ] Monitor: `fly logs --app emakola`, Postgres memory headroom
      (1GB; pool math in memory — don't scale app machines past what the DB
      can hold connections for)
