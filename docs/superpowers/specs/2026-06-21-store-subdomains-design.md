# Store Subdomain Pretty URLs — Design

## Context
Beautify storefront URLs: `makola.io/s/tiny-stitches/cart` → **`tiny-stitches.makola.io/cart`**.

**Decisions (from brainstorming):**
- **Subdomains, serve-in-place** — the branded host stays in the address bar (not a 301 to the subfolder).
- **Canonical stays the subfolder** — `rel=canonical` + sitemap keep pointing to `makola.io/s/:slug`, so SEO authority stays consolidated on the strong apex (our original strategy). Pretty for users, unchanged for ranking.
- **Every store auto-gets `<slug>.makola.io`** (reserved-word guarded). No merchant action required.

> **Implementation note (2026-06-21):** shipped via *implicit* resolution, not
> provisioned `StoreDomain` rows. `ResolveStoreByHost` serves `<slug>.<base>` in
> place with no row (reserved-guarded), so "every store auto-gets a subdomain"
> needs no provisioning change or backfill (the plan's Tasks 4–5 were dropped).
> Explicit rows still exist for custom vanity labels / custom domains and take
> precedence. This also resolves a collision with the pre-existing manual claim panel.

## What already exists (reuse — most of the *serving* is built, ship-dark)
- **`Emakola.Stores.StoreDomain`** — host→store map; `host` (unique, normalized), `type` (:subdomain/:custom), `serve_in_place?`, `primary?`, `status`, `verified_at`.
- **`EmakolaWeb.Plugs.ResolveStoreByHost`** (in the endpoint, before the router) — default 301→`/s/:slug`; when the `StoreDomain` has `serve_in_place?: true`, it **rewrites `conn.path_info`** to `["s", slug | rest]` and serves in place. Gated on `config :emakola, :store_subdomain_base` (env `STORE_SUBDOMAIN_BASE`, default nil = dark).
- **`EmakolaWeb.SEO.Canonical`** — apex-pinned `/s/:slug` URLs; already emits the correct canonical regardless of the request host (no change needed).
- **`store_address_live.ex`** — "storefront address" admin panel.
- `check_origin` already wildcards `*.<host>` (works once `PHX_HOST=makola.io`).

## The actual new work
1. **Host-aware storefront link generation (the core "beautify").** A helper — `EmakolaWeb.Storefront.Path.path(socket_or_conn, store, subpath)` — that returns `"/<subpath>"` when the current request is on that store's own subdomain, and `"/s/:slug/<subpath>"` otherwise (apex, or a different store's host). The storefront LiveViews/components/templates use it for **internal** links (cart, product, category, account, etc.) instead of hardcoding `/s/:slug/...`.
   - "Am I on this store's subdomain?" is decided by a flag set during host resolution (`ResolveStore`/`ResolveStoreByHost` assigns e.g. `@on_store_subdomain?`), so the helper doesn't re-parse the host.
   - Canonical/sitemap/OG (cross-store, SEO) keep using `SEO.Canonical` (apex `/s/:slug`) — only **navigational** links go through the new helper.
2. **Auto-provision a `StoreDomain` per store.** On store create (and a one-off backfill for existing stores), create `host: "<slug>.<base>"`, `type: :subdomain`, `serve_in_place?: true`, `primary?: true` — only when `store_subdomain_base` is set (else skip; stays dark). Reserved-word guard (reuse the existing `ValidStoreHost`/reserved-subdomain check). Skip/realias on slug collision.
3. **Slug changes.** When a store's slug changes, regenerate its primary subdomain to match (and optionally keep the old host as a non-primary 301 alias). Keep it simple: update the primary `StoreDomain.host`.

## Architecture / data flow
1. Visitor hits `tiny-stitches.makola.io/cart` → `ResolveStoreByHost` finds the `StoreDomain` (serve_in_place) → rewrites `path_info` to `["s","tiny-stitches","cart"]` and assigns `on_store_subdomain?: true` → router matches the normal storefront route → page renders.
2. Page's internal links call `Storefront.Path.path(socket, store, "cart")` → `"/cart"` (because `on_store_subdomain?`). Canonical via `SEO.Canonical.store_url/1` → `https://makola.io/s/tiny-stitches`.
3. On the apex (`makola.io/s/tiny-stitches/...`) the same helper returns `/s/tiny-stitches/cart` (subdomain flag false). Both work.

## Error handling / edges
- `store_subdomain_base` unset → no auto-provision, `ResolveStoreByHost` is a pass-through, the helper always returns `/s/:slug/...`. Fully dark.
- Reserved slugs (`www`, `admin`, `api`, `app`, `mail`, `blog`, `s`, …) → no subdomain provisioned; store stays on `/s/:slug`.
- Unknown/unverified host → `ResolveStoreByHost` falls through (404/apex), no leak.

## Security
- Host strings handled as strings (normalized lowercase); **no `String.to_atom`** on hostnames.
- Tenant resolution unchanged (store from the resolved `StoreDomain`); no cross-store leakage (the path rewrite carries the store's own slug).

## Testing
- `Storefront.Path.path/3`: subdomain → `/subpath`; apex → `/s/:slug/subpath`; different-store host → `/s/:slug/subpath`.
- `ResolveStoreByHost` serve-in-place: rewrites path_info + sets the subdomain flag (already partly covered — extend).
- Auto-provision: new store → `StoreDomain` (serve_in_place, primary) created when base set; skipped when dark or reserved slug; slug change updates the host.
- Storefront render on a subdomain: internal links are `/cart` (no `/s/`), canonical = apex `/s/:slug`.
- Backfill task creates subdomains for existing stores idempotently.
- `mix test` / `format` / `credo` clean.

## Activation (ops — nothing changes until done)
1. `fly certs add '*.makola.io'` + wildcard DNS (Namecheap `*.makola.io` → Fly A/AAAA).
2. `fly secrets set STORE_SUBDOMAIN_BASE=makola.io`.
3. Backfill subdomains for existing stores (a mix task / one-off).

## Out of scope
- Custom domains (`yourshop.com`) — Phase 6, paid tier.
- Subdomain-as-canonical (explicitly rejected — canonical stays the subfolder).
- Non-storefront URL changes.

## Sequencing
Independent of the open WhatsApp PR (#185). Branch off main; activation gated on the wildcard cert + `STORE_SUBDOMAIN_BASE`.
