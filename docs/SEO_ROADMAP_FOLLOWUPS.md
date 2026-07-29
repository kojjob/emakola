# SEO Roadmap — Remaining Follow-ups

**As of 2026-06-20.** The low-cost SEO / AI-SEO + merchant-domains roadmap
(Phases 0–6) is **built through Phase 5**, all **ship-dark** (each feature
no-ops safely until its key/DNS switch is flipped). Smoke-tested live: the
indexable SEO surface (canonical-pinned pages, sitemap enumeration, JSON-LD,
the thin-content noindex guardrail, footer internal-linking) renders correctly.

Per-phase PRs: #164 (P0) · #165 (P1) · #166 (P2) · #167 (P3a) · #168 (P4) ·
#169 (P5 GSC) · #170 (P5 linking) · #171 (P3b+3c recovery).

📖 **Plain-English step-by-step how-tos** for the switches, backlinks/social, and
custom domains: **`docs/SEO_PLAYBOOK.md`**.

> Historical status note: this file records the June 2026 roadmap and PR state.
> For the current implementation audit and priorities, use
> **`docs/SEO_AI_SEARCH_AUDIT_2026-07-29.md`**. Do not infer current merge or
> rollout status from the old checkboxes below.

---

## 1. Merge the open PRs — do first

- [ ] **#171 — land stranded Phase 3b + 3c.** ⚠️ **Critical:** PR #167 merged at
      the Phase 3a tip, so the AI **workers** (`ProductSEOWorker`,
      `ImageAltTextWorker`, `BlogGeneratorWorker`), the **`RateLimiter`**, and the
      **`/admin/seo`** dashboard never reached main. Without #171, main has the
      AI generator but nothing to invoke it, and `/admin/seo` 404s.
- [ ] **#169 — Phase 5 GSC fetcher.**
- [ ] **#170 — Phase 5 footer internal-linking.**

## 2. Activation switches — flip when ready (all currently dark)

- [ ] **makola.io DNS cutover** (one coordinated flip): set `PHX_HOST=makola.io`,
      populate `:canonical_redirect_hosts` (= `emakola.com`, `www.emakola.com`,
      `emakola.fly.dev`, `emakola.io`), move email `*@emakola.com` → makola.io,
      update the `robots.txt` sitemap URL. Do it **after** the apex DNS + TLS exist.
- [ ] **`STORE_SUBDOMAIN_BASE=makola.io`** — turns on branded subdomains (Phase 2).
      Needs a **`*.makola.io` wildcard DNS + TLS cert** first, or branded hosts
      hit a cert error.
- [ ] **`ANTHROPIC_API_KEY`** — turns on AI content generation (Phase 3).
      Hard-capped at 50 generations/store/day; budget ~$5–20/mo at launch volumes.
- [ ] **`:gsc_credentials`** (+ optional `:gsc_site_url`) — turns on the GSC
      fetcher (Phase 5). Needs a GSC-verified property + a Goth token (see §4).

## 3. Deferred roadmap features — build when worthwhile

- [ ] **Phase 3c — "Generate with AI" form buttons** on the product form + post
      editor (inline `start_async` fill). Deferred: redundant with the `/admin/seo`
      bulk dashboard for products; the per-form button is the convenience layer.
- [ ] **Phase 4 — `/shops/:region/:category` pages.** Deferred: region×category
      combos are thin at current catalog volume (the guardrail would noindex most).
      Revisit once product volume grows. (Pattern + queries already exist via
      `EmakolaWeb.SEO.Regions` + `ShopsLive`.)
- [ ] **Phase 5 — backlinks / WhatsApp-share / social.** Ops/outreach, not code:
      Ghana business directories, merchant Instagram/Facebook/WhatsApp-business
      bios → `yourshop.makola.io`, local press/blogger outreach. (Auto-generated
      OG images is the one code option here, for later.)
- [ ] **Phase 6 — custom domains (`yourshop.com`), the paid tier.** Resolution
      code already exists (`ResolveStoreByHost` handles `StoreDomain` type
      `:custom`). Needs a **TLS decision** before it's buildable:
      (a) per-domain `fly certs add` (free, manual, first handful), or
      (b) Cloudflare for SaaS (~$0.10/hostname/mo, scales), or
      (c) plain **301** `yourshop.com → makola.io/s/slug` (brand-only, $0).
      Then: custom-domain admin UI (extend `Admin.StoreAddressLive`), flip
      `custom_domain_support: true`, add custom origins to `check_origin`. Charge for it.

## 4. Production wiring — when activating

- [ ] **GSC Goth token provider** — `GscFetcher` reads an access token from
      `:gsc_credentials`; wire a Goth service-account source (mirror the FCM/push
      Goth setup) to mint it, and set `:gsc_site_url` to the verified property.
- [ ] **Re-submit sitemaps in Search Console** and validate every page type in
      Google's Rich Results Test (Product/LocalBusiness, Article, Recipe, FAQ,
      region pages) once live on makola.io.

## 5. Carried over from the rebrand (not SEO-specific)

- [ ] **Logos** — `priv/static/images/logo.svg` + `emakola-logo.svg` are
      path-based wordmarks still rendering "emakola"; a designer must redraw to
      "makola". (The `alt` text is already "Makola".)
