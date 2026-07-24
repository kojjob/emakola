# Admin IA + Supply-Surface Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regroup the 24-entry merchant sidebar into six labeled sections with the Marketplace renames (+ copy ripple), scope announcements to the dashboard, and lift the three supply pages to the Makola Admin design language.

**Architecture:** Markup/titles/copy only — zero route, `active_nav`, or domain changes. Spec: `docs/superpowers/specs/2026-07-24-admin-ia-polish-design.md`. Branch `feature/admin-ia-polish` is based on PR #342's tip; its PR merges after #342.

**Tech Stack:** Phoenix LiveView, TailwindCSS, ExUnit.

## Global Constraints

- TDD where behavior changes (copy assertions, announcement scoping, thumbnails); title renames update existing assertions in the same commit.
- ALL commands FOREGROUND — never background, never wait on notifications; full suite ~5 min, run it and wait (parse the "Result:" line).
- Hrefs and `active_nav` atoms are FROZEN — only visible titles, section labels, ordering, and copy change.
- Renames (exact): "Supplier Catalog" → **"Browse Suppliers"**; "Earn Network" → **"Partners"**; "Suppliers" → **"My Contacts"**. Sections: Main / Sell / Marketplace / Customers & Marketing / Content & Design / Insights (bottom block unchanged).
- Copy ripple: every user-facing "Earn Network" becomes "Partners" — `lib/emakola/notifications/templates.ex` (requested SMS + any whatsapp param naming), `lib/emakola_web/live/admin/supply_catalog_live/show.ex` (`:unavailable` notice + `:connection_exists` flash), the offers-index empty state / Earn-catalog banner if they name it. Grep `Earn Network` across `lib/` and `test/` and update pairs together. `docs/PROVIDER_SETUP.md` §4c only if its template body names the page (verify).
- Visual work follows the **frontend-design skill** (load it in the implementer) and the existing Makola Admin patterns: `nav-section-label` for section headers, stat tiles as on the merchant dashboard, thumbnail blocks as on the catalog cards.
- `mix format`; focused files green per task; `MIX_ENV=test mix compile --warnings-as-errors` (touch edited files first); conventional commits.

---

### Task 1: Sidebar regroup + renames + copy ripple

**Files:**
- Modify: `lib/emakola_web/components/sidebar_components.ex` (reorder into sections per spec §1 — reuse the existing `nav-section-label` paragraph style used by "Main"/"Marketing"; move Categories under Sell)
- Modify: `lib/emakola/notifications/templates.ex`, `lib/emakola_web/live/admin/supply_catalog_live/show.ex`, `lib/emakola_web/live/admin/supply_offers_live/index.ex` + `supply_network_live.ex` banner (grep-driven)
- Test: `test/emakola_web/live/admin/supply_offers_live_test.exs` (sidebar section test added to the index describe), `test/emakola/notifications/templates_test.exs` + `test/emakola/notifications/workers/connection_notification_worker_test.exs` + `test/emakola_web/live/admin/supply_catalog_live_test.exs` (copy assertions updated)

**Steps:** (1) `grep -rn "Earn Network" lib/ test/` — enumerate every site; write/adjust the failing tests FIRST: new sidebar test asserts the six section labels + "Browse Suppliers"/"Partners"/"My Contacts" titles each wrapped in links to the UNCHANGED hrefs; template tests assert "Partners page" copy. (2) Watch fail. (3) Reorder/rename the sidebar; update copy sites. (4) Focused suites green: the four test files above. (5) Commit `feat(web): marketplace sidebar sections and partner naming`.

---

### Task 2: Announcements render on the dashboard only

**Files:**
- Modify: wherever the announcement banner renders (grep `Dismiss announcement` / the announcements component — likely the admin shell layout; scope its render to `@active_nav == :dashboard` or the dashboard template)
- Test: `test/emakola_web/live/dashboard_live_test.exs` (renders banner) + one other admin LV test file (refutes it)

**Steps:** (1) Verify dismissal persists: read the Dismiss handler — it must write `AnnouncementDismissal`; if it does not, add that (TDD). (2) Failing tests: dashboard shows an active announcement; `/admin/supply/offers` does NOT. (3) Scope the render. (4) Green + commit `fix(web): platform announcements live on the dashboard only`.

---

### Task 3: Supply-surface polish (load the frontend-design skill first)

**Files:**
- Modify: `lib/emakola_web/live/admin/supply_offers_live/index.ex` (thumbnail block before the title/meta column — mirror the catalog card's `first_image_url` + fallback-icon pattern), `lib/emakola_web/live/admin/supply_offers_live/form.ex` (`:edit` product header: thumbnail + product title + status pill above the model section; region rows: fee input right-aligned in-row, `grid-cols-1 sm:grid-cols-2` stays), `lib/emakola_web/live/admin/supply_catalog_live/show.ex` (connected state: three stat tiles — Suggested retail / Wholesale / Your margin "GH₵ X (Y%)" — above the variants table; single-variant offers read tiles from that variant, multi-variant show ranges; mirror the dashboard `kpi_cards`/stat-tile markup)
- Test: append to the two supply LV test files: offers index renders an `img` for an offer whose product has an image and the fallback block when not; catalog show (connected) renders the three tile labels; form `:edit` shows the product title in the header.

**Steps:** TDD as above → implement → focused suites green → `mix format` → commit `feat(web): supply surfaces join the admin design language`.

---

### Task 4: Mobile pass + gates

**Steps:** (1) Review the three supply pages' templates for <640px issues (long store names, the 16-region grid, stat tiles stacking, flex rows that should wrap) — fix with responsive classes only; no redesign. (2) Full gates FOREGROUND: `mix format --check-formatted`; `mix credo --strict` on touched lib files; `MIX_ENV=test mix compile --warnings-as-errors`; FULL `mix test 2>&1 | tail -3`. (3) Commit `polish(web): supply surfaces at phone width`. Do NOT push — the controller runs visual verification (Playwright, desktop + 375px) and the whole-branch review first.
