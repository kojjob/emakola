# Company & Footer Pages — Design

**Date:** 2026-06-15
**Status:** Approved design (brainstormed), pending implementation plan

## Goal

Build 8 production-grade, responsive company/legal pages for the Emakola apex
marketing site — **About, Careers, Press, Contact, Legal, Privacy Policy, Terms
of Service, Cookie Policy** — matching the existing landing-page aesthetic, and
wire up the currently-dead footer links that point to them.

## Context (current state)

- Marketing pages are LiveViews in the apex `scope "/"` (`pipe_through :browser`):
  `LandingLive` (`/`), `PricingLive` (`/pricing`), `StoresLive` (`/stores`),
  `Docs.DocsLive` (`/docs`). Each uses `layout: false`, imports `landing_nav/1`
  and `landing_footer/1` from `EmakolaWeb.LandingComponents`, sets SEO assigns
  (`page_title`, `meta_description`, `og_image`, `canonical_url`, optional
  `json_ld`), and a `toggle_mobile_menu` event.
- Aesthetic: white body (`bg-white font-body antialiased`), dark headings
  (`#0c1526`), muted text (`#5f6b7a`/`#8896ab`), dark footer (`bg-[#0c1526]`,
  borders `#1a2744`). `font-headline` for titles, `font-body` for prose.
- `landing_footer/1` (`landing_components.ex`) has **Company** (About, Careers,
  Press, Contact) and **Legal** (Privacy Policy, Terms of Service, Cookie Policy)
  columns whose links all point to dead `href="#"`.
- The storefront `/about` is tenant-scoped under `/s/:store_slug/about`
  (`:storefront` live_session) — **no collision** with an apex `/about`.
- Swoosh mailers exist under `Emakola.Notifications.Mailers.*`
  (`auth_mailer`, `billing_mailer`, `invite_mailer`, `platform_invite_mailer`).

## Architecture

8 LiveViews under `lib/emakola_web/live/company/`, namespace `EmakolaWeb.Company.*`,
each mirroring the `PricingLive` shape (`use EmakolaWeb, :live_view`,
`layout: false`, import `landing_nav`/`landing_footer`, SEO assigns,
`toggle_mobile_menu`). Rejected alternatives: controller+static HEEx (breaks the
LiveView mobile-menu nav), and one parametrized LiveView (jams 8 unrelated
contents + long legal prose into one module).

### Routes (added to the apex marketing `scope "/", EmakolaWeb` block)

```elixir
live "/about", Company.AboutLive
live "/careers", Company.CareersLive
live "/press", Company.PressLive
live "/contact", Company.ContactLive
live "/legal", Company.LegalLive
live "/privacy", Company.PrivacyLive
live "/terms", Company.TermsLive
live "/cookies", Company.CookiesLive
```

### New files

- `lib/emakola_web/live/company/about_live.ex`
- `lib/emakola_web/live/company/careers_live.ex`
- `lib/emakola_web/live/company/press_live.ex`
- `lib/emakola_web/live/company/contact_live.ex`
- `lib/emakola_web/live/company/legal_live.ex`
- `lib/emakola_web/live/company/privacy_live.ex`
- `lib/emakola_web/live/company/terms_live.ex`
- `lib/emakola_web/live/company/cookies_live.ex`
- `lib/emakola_web/components/company_components.ex`
- `lib/emakola/notifications/mailers/contact_mailer.ex`
- Tests mirroring each under `test/emakola_web/live/company/` and
  `test/emakola/notifications/mailers/contact_mailer_test.exs`.

### Modified files

- `lib/emakola_web/router.ex` — add the 8 routes.
- `lib/emakola_web/components/landing_components.ex` — rewire footer Company/Legal
  links from `href="#"` to the new routes.
- `config/runtime.exs` / `config/config.exs` — `:contact_email`, `:careers_email`,
  `:press_email`, `:support_whatsapp`, `:support_phone` (env-overridable; sane defaults).

## Shared components (`company_components.ex`)

- `page_hero(eyebrow, title, subtitle)` — centered hero band (eyebrow pill +
  `font-headline` title + muted subtitle), used by About/Careers/Press/Contact/Legal.
- `legal_layout(title, last_updated, sections)` — the legal-document chrome:
  desktop two-column (sticky table-of-contents nav built from section anchors +
  prose column), "Last updated {date}" line, and a disclaimer banner ("This is a
  template for information only, not legal advice — have it reviewed by qualified
  counsel before relying on it."). Mobile: single column, TOC becomes a collapsible
  `<details>` at the top. Prose styled with explicit Tailwind classes (headings,
  paragraphs, lists, links) — does **not** assume `@tailwindcss/typography`.
- `value_card(icon, title, body)`, `stat(value, label)`, `cta_band(title, subtitle, primary_cta, secondary_cta)`,
  `benefit_item(icon, title, body)` — small marketing building blocks.

Each is a function component with `attr`/`slot` declarations, matching the
existing component style.

## Per-page content

Marketing copy is written in this work (the user can edit later). Legal copy is
comprehensive template copy tailored to Emakola, **not** lawyer-reviewed.

- **About** (`/about`) — hero ("Building commerce for West Africa"); mission &
  story (2–3 paragraphs: why Emakola, the merchant problem, mobile-first West
  Africa); 4 value cards; a positioning band using **qualitative copy only**
  (e.g. "Built for West African merchants", "Mobile money first", "Low-bandwidth
  ready") — **no invented hard metrics** (don't fabricate store/GMV numbers);
  `cta_band` → Careers + register.
- **Careers** (`/careers`) — hero; "life at Emakola" culture section; benefits
  grid (remote-friendly, ownership, impact, learning, etc.); "No open roles right
  now — send your CV to careers@" general-application card (mailto); `cta_band`.
- **Press** (`/press`) — hero; short + long company boilerplate; key facts list
  (founded, HQ, markets: Ghana → Nigeria, what we do); **brand assets** section
  with downloadable logo files from `priv/static/images` (link to existing logo
  PNG/SVG; note exact filenames during planning); press contact (press@).
- **Contact** (`/contact`) — two-column on desktop: **(left)** working form —
  fields name, email, subject, message; client + server validation; a hidden
  honeypot field named `company_url` (visually hidden, `tabindex=-1`,
  `autocomplete=off`) that, if filled, silently drops the
  submission. On valid submit → `ContactMailer.deliver_contact_message/1` to
  `:contact_email`; show a success flash and reset the form. **(right)** channels:
  email, WhatsApp click-to-chat (`https://wa.me/<number>`), phone (`tel:`),
  support hours. Mobile: channels stack below the form. No DB persistence
  (email-only, YAGNI). Basic abuse mitigation: honeypot + per-LiveView-process
  simple throttle (e.g. ignore submits faster than N seconds apart).
- **Legal** (`/legal`) — hero + hub: cards linking to Privacy / Terms / Cookie,
  each with its "Last updated" date and a one-line description; brief note on how
  to contact for legal/compliance questions.
- **Privacy Policy** (`/privacy`) — `legal_layout`. Sections: Introduction; Who we
  are (Emakola, multi-tenant marketplace; merchant vs. platform roles); Information
  we collect (account, store, order, payment metadata, device/usage, cookies);
  How we use it; Payment processing (Paystack, Hubtel, mobile money — we don't
  store full card/PIN data); Sharing & third parties; Data retention; Security;
  Your rights (access, correction, deletion, objection); Children; International
  transfers; Changes; Contact.
- **Terms of Service** (`/terms`) — `legal_layout`. Sections: Acceptance;
  Definitions; Eligibility & accounts; Merchant obligations; Acceptable use /
  prohibited goods; Payments, fees & payouts; Orders & fulfillment between
  merchants and customers; Intellectual property; Third-party services;
  Disclaimers & limitation of liability; Indemnification; Suspension & termination;
  Governing law (Ghana, expanding); Changes; Contact.
- **Cookie Policy** (`/cookies`) — `legal_layout`. Sections: What cookies are;
  Why we use them; Categories (strictly necessary — session/cart/CSRF; functional;
  analytics; the PWA service-worker caches); Managing/disabling cookies (browser
  controls); Third-party cookies; Changes; Contact.

## Contact backend

`Emakola.Notifications.Mailers.ContactMailer` (Swoosh, same pattern as the other
mailers): `deliver_contact_message(%{name, email, subject, message})` builds an
email to `Application.get_env(:emakola, :contact_email)` with the sender's email
as reply-to, and delivers via the app's Swoosh mailer. Returns `{:ok, _}` /
`{:error, _}`. No new resource/table.

## SEO

Each page sets `page_title`, `meta_description`, `canonical_url` (via `url(~p"/...")`),
and reuses the existing `og_image`. Legal pages may omit `json_ld`. Add the new
public URLs to the platform sitemap if the sitemap enumerates marketing pages
(verify `SitemapController` during planning).

## Testing (TDD)

- **Per page:** LiveView test — `live/2` returns `{:ok, _, html}` (200), the page
  renders its primary `<h1>`/headline and a known section, and the shared nav +
  footer are present.
- **Routing:** each of the 8 paths resolves (covered by the per-page mounts).
- **Footer:** a test asserting `landing_footer` renders real hrefs for Company/Legal
  (e.g. `/about`, `/privacy`) and no `href="#"` remains in those two columns.
- **Contact form:**
  - invalid input (blank/invalid email) → renders validation errors, no email sent;
  - honeypot filled → submission silently dropped, no email sent, no error leak;
  - valid input → `ContactMailer` invoked (assert via Swoosh test adapter /
    `assert_email_sent`), success flash shown, form reset.
- **ContactMailer unit test:** builds an email to the configured address with the
  right subject/body and reply-to.

## Responsive

Mobile-first. Heros scale (`text-3xl lg:text-5xl`). Legal TOC collapses to a
`<details>` on mobile, sticky sidebar on `lg+`. Contact form stacks above channels
on mobile, side-by-side on `lg+`. Card grids `grid-cols-1 sm:grid-cols-2 lg:grid-cols-3`.
All interactive targets ≥ 44px; respects the low-bandwidth, mobile-first directive.

## Out of scope

- A CMS/DB for careers openings or press releases (static content now).
- Persisting contact submissions to a database (email only).
- Lawyer-reviewed legal text (template copy with a disclaimer; counsel review is
  the user's responsibility before launch).
- Localization/translation of these pages (English only for now).
- Storefront (tenant) equivalents — these are apex-only.
