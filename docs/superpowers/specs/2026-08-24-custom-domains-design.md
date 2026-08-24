# Merchant Custom Domains — Design

**Date:** 2026-08-24 · **Status:** approved, implementation in slices A–H

## Context

A merchant should be able to point `kentekingdom.com` at their Makola storefront, have it load over HTTPS on their own domain, and have that domain become the store's canonical URL in Google.

**Why now:** `lib/emakola_web/live/pricing_live.ex:180` already sells "Custom domain" on the GHS 79 tier and `docs/BUSINESS_MODEL.md:17` lists it as a paid feature. Nothing implements it. `docs/SEO_PLAYBOOK.md:161-218` has been parked waiting on one business decision — how domains get TLS certificates — which is now made.

**What already exists (ships dark):** roughly 70% of the *routing*. `StoreDomain` already has `type: :custom`, `status: :pending`, `verified_at` columns, and the host-based storefront catch-all (`router.ex:602-635`) already serves any unrecognised host at root. Missing is everything that makes those columns reachable and safe: no action can write `status` or `verified_at`, and the DB default is `:active`, so anything created today is instantly live and unverified.

**Decisions locked with Kojo:** TLS via Fly certificates provisioned by the app itself; assisted flow with a staff-approval gate; no commercial gating for now; **a live custom domain becomes the store's canonical.**

That last one **reverses** the Phase-0 stance in `store_domain.ex:11-14` ("the page's canonical still points at the subfolder"). Deliberate — a merchant paying for their own domain and still seeing `makola.io` in Google is the feature not working. Both that moduledoc and `canonical.ex`'s get updated to say so.

**Where the staff gate sits — settled, not deferred.** Approval is the `:pending → :verifying` transition: a human reviews *before* we spend a Fly certificate slot and Let's Encrypt quota, and the flip to live is automatic once Fly reports `Ready`. Front-gating *is* assisted approval — it is the point at which a human can still prevent something (a squatted domain, an abusive store), whereas after a certificate issues there is nothing a human can usefully add but latency. The documented alternative, if it's ever wanted: make `mark_active` staff-triggered instead of worker-triggered, a one-line inversion.

---

## Verified external facts

Checked live against the real `emakola` Fly app, not recalled:

- `mutation addCertificate(appId: ID!, hostname: String!)` → `AddCertificatePayload { certificate, check, errors }`; `deleteCertificate(appId:, hostname:)`; read via `app(name:){ certificate(hostname:){…} }`
- `AppCertificate`: `clientStatus`, `isConfigured`, `isApex`, `isAcmeAlpnConfigured`, `dnsValidationHostname`, `dnsValidationTarget`, `rateLimitedUntil`, `validationErrors`
- A live read of `www.makola.io` returned `clientStatus: "Ready"` — that string is the success signal. Others in the wild: `"Awaiting configuration"`, `"Awaiting certificates"`.

🔴 **App IPv4 `66.241.124.228` is SHARED; IPv6 `2a09:8280:1::126:6f75:0` is DEDICATED.** Fly needs an AAAA record, an `_acme-challenge` CNAME, or a `_fly-ownership` TXT to issue. An **apex** custom domain therefore needs **both A and AAAA**, or the certificate hangs at "Awaiting configuration" forever. This is the single most likely reason a merchant's domain never goes live, and it shapes the DNS card.

🔴 **Fly's GraphQL returns HTTP 200 with an `"errors"` key on failure.** `lib/emakola/http_client/req.ex` maps 200 → `{:ok, body}`, so the client must inspect `body["errors"]` itself — otherwise every failure looks like success.

Because Fly's `HostnameCheck` already reports resolved records, **no DNS resolver of our own** — no `:inet_res`, no new dependency.

---

## Security holes this must close

All verified in code; unreachable today only because nothing creates a `:custom` row.

1. **Apex hijack.** `plugs/resolve_store_by_host.ex:53-59` passes through only `base` and `www.<base>` and runs in the **endpoint, before** the router's `@apex_hosts` scope. A `:custom` row for `emakola.fly.dev` would 301 the platform's own host to a merchant's store. Compounding it, `validations/valid_store_host.ex:39` applies the reserved-word check **only when `type == :subdomain`**.
2. **Squatting.** `identity(:unique_host, [:host])` is global with no ownership proof — merchant A claims `nike.com`, the real owner never can.
3. **Self-301 loop.** Once canonical is the custom domain, a `serve_in_place?: false` custom row 301s to itself (`resolve_store_by_host.ex:71`).
4. **`primary?` has no uniqueness.** Harmless today; a correctness bug the moment canonical depends on it.

---

## Slice graph

Every slice branches from `main`. **Nothing is stacked** — the cascade trap has destroyed work in this repo three times.

```
A  host guard          ─┐
B  state machine       ─┼── independent, any merge order
C  Fly certs client    ─┘
                        ├─ D  workers        (needs B + C on main)
                        ├─ E  check_origin   (needs B)
                        ├─ F  canonical+loop (needs B)
                        ├─ G  merchant UI    (needs B)
                        └─ H  staff queue    (needs B)
```

Only D has two parents. That flatness comes from three placements: the cached resolver and `DomainInstructions` both live in **B**, and **H's activate button transitions state only — it never calls Fly**, so H lands before D exists.

Inert until used: nothing resolves until a `:custom` row reaches `:active`; no Fly call fires until `FLY_API_TOKEN` is set.

---

## Slice A — Close the apex hijack

| File | Change |
|---|---|
| `config/config.exs` | `config :emakola, :apex_hosts, ~w(makola.io www.makola.io emakola.com www.emakola.com emakola.fly.dev localhost 127.0.0.1)` |
| `lib/emakola_web/router.ex:10` | `@apex_hosts Application.compile_env(:emakola, :apex_hosts)` — one list, two readers |
| `lib/emakola/stores/validations/valid_store_host.ex` | new reject branch applying to **all** types |

`@apex_hosts` must stay compile-time (`scope host:` requires it), but `PHX_HOST` and `:canonical_redirect_hosts` are runtime. So the validation computes the union at validation time and exports `platform_host?/1` publicly — slice E reuses it as its zero-DB short-circuit:

```
platform_host?(host) =
  host in compile_env(:apex_hosts)
  or host == PHX_HOST or host == "www." <> PHX_HOST
  or host in get_env(:canonical_redirect_hosts, [])
  or host == base or String.ends_with?(host, "." <> base)
  or reserved_label?(host)          # now applied to :custom too
```

Error message is deliberately vague — `"is not available"`, not a list of platform hosts.

**Tests first** (`test/emakola/stores/validations/valid_store_host_test.exs`, new): each of `emakola.fly.dev` / `makola.io` / `www.emakola.com` / `localhost` / `admin.example.com` / `kente-kingdom.makola.io` rejected as `:custom`; `kentekingdom.com` and `shop.kentekingdom.com` accepted; `platform_host?/1` shifts when the endpoint host changes. **Regression: existing `:subdomain` create tests stay green.**

**Verify:** `mix test test/emakola/stores/ test/emakola_web/plugs/resolve_store_by_host_test.exs`. Put the config key in `config/config.exs`, not `runtime.exs` — a `nil` from `compile_env` fails `scope host:` at compile time.

---

## Slice B — Verification state machine + cached resolver

The keystone; everything except A and C hangs off it.

### States

**Do not flip the DB default of `status`.** `StoreAddressLive` (subdomain path) relies on `:active` being the default; a global flip breaks it and its green tests, costing B its independent mergeability. Set status **per action** instead.

`constraints(one_of: [:pending, :verifying, :active, :expired])` — purely additive, since both plugs match `status: :active` (`resolve_store_by_host.ex:70`, `resolve_store_host.ex:76`), so every new state is inert to routing by construction.

| State | Meaning | Entered by | Live? |
|---|---|---|---|
| `:pending` | Submitted, awaiting staff review | merchant | no |
| `:verifying` | Staff approved; cert requested, DNS polling | staff | no |
| `:active` | Fly `clientStatus == "Ready"` | worker | **yes** |
| `:expired` | Never configured in time, or revoked. Terminal — **releases the host** | sweeper / staff | no |

New attributes: `status_reason :string` (last Fly message / expiry reason, shown to merchant and staff) and `verifying_since :utc_datetime_usec` (the expiry clock — `updated_at` can't serve, every poll rewrites it).

### How `status`/`verified_at` become writable safely

They never enter an `accept` list. Each transition is a named action with `accept([])` + `change(set_attribute(...))` — the in-repo pattern at `stores/resources/store.ex:500-525` and `store_verification.ex:145-159`.

```
create :create              # UNCHANGED — do not touch the subdomain path
create :claim_custom        # accept([:store_id, :host]); forces type: :custom,
                            #   status: :pending, serve_in_place?: true, primary?: false
create :claim_custom_alias  # the automatic "www." sibling; serve_in_place?: false
update :update              # accept-list UNCHANGED; + validate SafePrimaryDomain
update :request_verification  # staff: :pending → :verifying, stamps verifying_since
update :record_check          # worker progress note; stays :verifying
update :mark_active           # worker: :verifying → :active, stamps verified_at
update :expire                # :expired + clears primary? + nils verified_at
update :make_primary          # requires :active; DemoteSiblingPrimaries first
read   :list_custom_for_review / :list_verifying / :get_primary_by_slug
```

`SafePrimaryDomain` guards the merchant-facing `:update` (which accepts both fields): reject `primary?: true` when `status != :active`; reject `serve_in_place?: false` on a primary `:custom` row — that is precisely the self-301 loop.

`DemoteSiblingPrimaries` runs in `before_action` and must **demote before promote**, or the partial unique index rejects the write. `require Ash.Query` at module level.

### Identities — two partial unique indexes

```elixir
identity(:unique_host, [:host], where: expr(status != :expired))
identity(:one_primary_per_store, [:store_id], where: expr(primary? == true))
```

Precedent: `suppliers/resources/preorder_deposit.ex:34`. The `unique_host` change **is** the squatting fix — an expired reservation stops holding `nike.com` hostage. Migration drops `store_domains_unique_host_index` first. An identity on `[:store_id, :primary?]` would be wrong (it forbids two `false` rows).

### 🔴 Cache invalidation trap

`StoreCache.invalidate_store/2` **cannot reach the new keys.** `key_belongs_to_store?/2` (`cache/store_cache.ex:317-322`) splits on `":"` into exactly three parts and requires the middle to equal `store_id`; neither new key has that shape. So a global `change InvalidateDomainCache, on: [:create, :update, :destroy]` explicitly invalidates **both** `"domain_host:<host>"` (plus the old host if `:host` changed) and `"store_primary_host:<slug>"`, via `after_transaction/2` — not `after_action`, so a rolled-back transaction never poisons the cache.

### `Emakola.Stores.DomainResolver` (new)

`lookup/1`, `primary_host/1`, `invalidate/1`, `invalidate_slug/1`.

`lookup/1` caches a **minimal map**, never a `%StoreDomain{}` with a loaded `:store` — a cached store struct would serve stale themes and stale suspension status. `StoreCache.fetch/4` only caches `{:ok, value}`, so return `{:ok, :none}` on a miss and map it at the boundary; that is how negative results get cached, which slice E depends on. Positive TTL 5 min, **negative TTL 60 s** to bound bot probing.

### `Emakola.Stores.Domains` (new service module)

`claim/3`, `request_verification/2`, `mark_active/1`, `expire/2`, `revoke/2`. The single place D/G/H call. `request_verification/2` and `expire/2` are the two seams D later reopens — a normal edit to a landed `main` file, not a stack.

### `Emakola.Stores.DomainInstructions` (new, pure, no DB)

Lives in B so G and H both consume it without a second parent. Targets come from config (`:fly_dns_targets` in `runtime.exs`), never a literal in a template.

**Apex `kentekingdom.com` → three rows:**

| Type | Name | Value |
|---|---|---|
| `A` | `@` | `66.241.124.228` |
| `AAAA` | `@` | `2a09:8280:1::126:6f75:0` |
| `CNAME` | `www` | `emakola.fly.dev` |

The AAAA row is **not optional** (shared IPv4 — see Verified facts). The `www` row ships by default rather than on request: a merchant who adds only the apex gets a dead `www.` and, given the literacy constraint, will not diagnose it. That is why `Domains.claim/3` creates the `www.` sibling row automatically.

**Subdomain `shop.kentekingdom.com` → one CNAME row.**

🔴 **The `www.` strip must NOT live in the shared `NormalizeHost`.** A merchant typing `www.kentekingdom.com` should get the apex treatment — but if the strip is shared, `claim_custom_alias` normalizes its own `www.kentekingdom.com` back to `kentekingdom.com` and the second insert collides with `identity(:unique_host, …)`, failing every apex claim inside the transaction. Put the strip in `claim_custom` only (a dedicated `NormalizeApexClaim` change), leaving `claim_custom_alias` to persist the `www.` host verbatim. Slice B's claim-orchestration tests are what catch a regression here.

**Tests first** — state machine (each transition guard, both directions); accept-list proof that `claim_custom` can't set `status`/`verified_at` even when passed; **regression: plain `:create` for a `:subdomain` still yields `:active`**; squatting release (expire `nike.com`, a *different* store re-claims); `make_primary` leaves exactly one primary; resolver caches negatives and invalidates on `mark_active`/`destroy`; **explicit proof that `invalidate_store/2` leaves both new keys intact**; `records_for/1` row counts for apex vs subdomain vs `www.`; `claim/3` creates 2 rows for an apex and rolls back the pair on sibling failure.

**Verify:** `mix test test/emakola/stores/`; `mix ecto.migrate && mix ecto.rollback` round-trip on the index swap.

---

## Slice C — Fly GraphQL certificate client

Pure I/O behind a project-owned module. Nothing imports it until D.

- `lib/emakola/infra/fly_certs_behaviour.ex` — `add_certificate/1`, `get_certificate/1`, `delete_certificate/1`
- `lib/emakola/infra/fly_certs.ex` — uses the injected `Emakola.HTTPClient`, read via `Application.get_env(:emakola, :http_client, Emakola.HTTPClient.Req)` exactly like `payments/paystack_client.ex:95-112`
- Mox `Emakola.Infra.FlyCertsMock` in `test_helper.exs`, wired in `config/test.exs`
- New env: `FLY_API_TOKEN`, `FLY_APP_NAME` (default `emakola`)

Normalize into a project-owned `%FlyCerts.Status{}` so no Fly field name leaks past this module. Ships dark: `{:error, :not_configured}` when the token is nil, with zero HTTP calls.

**Tests first** — exact mutation body and bearer header asserted via `HTTPClientMock`; `"Ready"` and `"Awaiting configuration"` both parsed; **HTTP 200 carrying `"errors"` → `{:error, _}`, not `{:ok, _}`**; unknown hostname → `{:ok, nil}`; `rateLimitedUntil` surfaced; unconfigured token makes no call.

**Verify:** `mix test test/emakola/infra/fly_certs_test.exs`, then one live read against `emakola` using the same query shape.

---

## Slice D — Oban workers (needs B + C)

Cron, not self-scheduling: this repo has **zero** self-rescheduling workers and uses `{:snooze, _}` nowhere. Match `analytics/workers/gsc_sync_worker.ex`.

- `config/config.exs` — add `domains: 3` to queues (low concurrency bounds Fly spend) and `{"*/10 * * * *", DomainSweepWorker}` to the crontab

**`DomainCertificateWorker`** — `queue: :domains, max_attempts: 3, unique: [period: 600, fields: [:worker, :args]]`, string-keyed args. Idempotent: non-`:verifying` row → `{:cancel, _}`; unconfigured Fly → `:ok` no-op; `get_certificate` first so `addCertificate` never fires twice; `"Ready"` → `mark_active` + notify merchant; otherwise `record_check` with a readable message from `validation_errors`/`rate_limited_until`; Fly error → `{:cancel, _}`, never a crash-retry.

**`DomainSweepWorker`** — cron, `max_attempts: 1`, `require Ash.Query`. Per `:verifying` row: older than `:custom_domain_verify_days` (default 7) → `Domains.expire/2`, which transitions to `:expired`, clears `primary?`, calls `delete_certificate/1` to free the Fly slot, invalidates both cache keys, and notifies. **This is both the "never configured" answer and the squatting release.** Otherwise enqueue a cert job.

D reopens two B seams: `request_verification/2` gains an immediate `Oban.insert` (so a merchant watching the screen sees progress in seconds, not 10 minutes), and `expire/2` gains `delete_certificate/1`.

**Tests first** — transition guards; add-once idempotency across two performs; unconfigured token → zero mock invocations; sweeper skips `:pending`/`:active`/`:expired`/`:subdomain`; 8-day-old row expires with `delete_certificate` called; **end-to-end squatting release: after expiry another store can claim the host**. `config/test.exs` already sets `Oban, testing: :manual`.

---

## Slice E — Host-aware `check_origin` (needs B)

Fires on **every socket connect** against `fly.toml` `soft_limit = 100`, and bots probe random `Host` headers. New `lib/emakola_web/origin_checker.ex`, four gates cheapest-first:

1. scheme is `https` (preserves current posture)
2. `ValidStoreHost.platform_host?/1` from slice A — **zero DB**, one shared list, no drift. It reads `:canonical_redirect_hosts` and `:store_subdomain_base` via `Application.get_env`; cheap, but on every connect. Worth precomputing the static portion into `:persistent_term` at boot and leaving only the runtime reads — a choice, not a blocker.
3. `DomainResolver.lookup/1` — ETS
4. DB, only on a cold miss; cached either way

Only `status: :active` gets a socket. `config/runtime.exs:413-430` becomes `check_origin: {EmakolaWeb.OriginChecker, :allowed?, []}`.

**CSP is not a blocker** — `plugs/content_security_policy.ex` emits `connect-src 'self' wss: ws:`, scheme-wildcarded, so this slice doesn't touch it.

🔴 **No test-env path exercises `check_origin`** (`dev.exs:74` is `false`, `test.exs` sets none). So verification is two-part, and the live half is mandatory: `check_origin` fails **silently** — the page renders, LiveView degrades to longpoll, and longpoll breaks across two Fly machines.

**Tests first** — `allowed?/1` against hand-built `%URI{}`: apex/www/`*.base`/fly.dev true with **zero queries** (gate-2 proof); active custom true; `:pending` and `:expired` **false**; unknown false and cached (negative-caching proof); `http://` false; a host flips false→true immediately after `mark_active` (this is the test that catches missing invalidation wiring).

**Verify — live, post-deploy:**
```bash
curl --http1.1 -i -sS -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" \
  -H "Origin: https://kentekingdom.com" \
  "https://kentekingdom.com/live/websocket?vsn=2.0.0"
```
Expect `101 Switching Protocols`. Re-run with `Origin: https://makola.io` — a regression there silently kills every existing storefront. Run this **after DNS has propagated**, so the request genuinely reaches the app on that host; against a not-yet-pointed domain it proves nothing. A `DNS_PROBE` failure here is usually a stale local resolver cache, not a broken record — check with `dig +short @8.8.8.8 <host>` before touching the registrar.

---

## Slice F — Canonical flips + self-301 loop (needs B)

**Do not touch the call sites.** Exactly **one** passes a bare `%{slug: slug}` map (`resolve_store_by_host.ex:71`); the other ~24 pass a real `%Store{}`. So resolve the primary host **inside** `store_base/1` (`seo/canonical.ex:43-52`), keyed on slug, and every call site keeps working:

```elixir
case DomainResolver.primary_host(slug) do
  host when is_binary(host) -> "#{scheme}://#{host}"   # custom domain wins
  nil -> <existing subdomain-base / apex-subfolder branch, unchanged>
end
```

Because canonical, OG, JSON-LD and the sitemap all already funnel through `store_base/1`, they flip together.

**Scope limit, deliberate:** `get_primary_by_slug` filters `type == :custom`. `StoreAddressLive` sets `primary?: true` on subdomain claims, so without that filter canonical would flip to a merchant-chosen label for every existing store — a behaviour change with green tests attached.

**Cold-cache read on disconnected mount** is mitigated by write-warming `"store_primary_host:<slug>"` inside the same `after_transaction` as `mark_active`'s invalidation. Note it in the PR rather than letting a reviewer find it.

**Self-301, two independent defences.** Structural (landed in B): `claim_custom` hard-sets `serve_in_place?: true` and `SafePrimaryDomain` forbids flipping it. Belt (3 lines here): compare the computed target host to `conn.host` before redirecting, passthrough if equal. The belt is what makes the `www.` sibling safe — `www.kentekingdom.com` 301s to the apex (different host, proceeds) while the apex row never redirects.

**Tests first** — no custom domain → canonical unchanged (all existing assertions green); active+primary → custom host across `store_url`/`path`/`product_url`/`category_url`; `:pending`/`:expired`/non-primary all fall back; **a primary `:subdomain` row does not change canonical** (scope-limit proof); canonical reflects `mark_active` immediately; self-301 passthrough; `www.` alias 301s with path+query preserved; sitemap `<loc>`s use the custom domain.

Conn tests must override `conn.host` — `test/support/conn_case.ex:37-46` pins it to `localhost`, and a custom host then falls to the unconstrained catch-all. **That is the mechanism working, not a bug.**

**Verify:** post-deploy `curl -sS https://kentekingdom.com | grep -i 'rel="canonical"'` self-references; `curl -sSI https://www.kentekingdom.com` returns 301 to the apex.

---

## Slice G — Merchant UI (needs B)

New `lib/emakola_web/live/admin/store_domain_live.ex`, route beside `router.ex:500`. Icon-led, ≤8 words per string.

One visual stepper: **1 Add these to your domain** (`:pending`) — the `DomainInstructions` table, each row a type badge plus one-tap copy on NAME and VALUE, no prose between rows, and a **"Send to WhatsApp"** button that shares the records as text (the merchant often doesn't hold the registrar login — highest-leverage affordance on the page). **2 Checking your domain** (`:verifying`) — spinner, `status_reason` if present, PubSub live update. **3 Your domain is live** (`:active`) — green check, host as a big tappable link. `:expired` — amber, reason, one "Try again".

🔴 **`StoreAddressLive` is linked from nowhere** — reachable only by typing `/admin/settings/address`. Add the nav link in `settings_live.ex` near the delivery link (line ~593) for the new page; **do not touch `StoreAddressLive` itself** — its duplicate-row bug is on the mention-don't-fix list and editing it drags the subdomain path into this diff.

**Tests first** — apex claim creates 2 rows and renders **exactly three** record rows including AAAA; subdomain renders one; `emakola.fly.dev` shows "is not available" and creates nothing (slice-A guard reaching the UI); each state renders its step; merchant of store A cannot mutate store B; no DB queries in disconnected mount; `store_address_live_test.exs` still green.

**Verify:** `mix test test/emakola_web/live/admin/`, plus a manual pass at 360px — the DNS table must not overflow.

---

## Slice H — Platform staff queue (needs B)

New `lib/emakola_web/live/platform/domain_live/index.ex`, modelled on `platform/verification_live/index.ex`. Route in the `live_session :platform` block; nav entry in `components/layouts.ex`.

`on_mount {RequirePermission, :manage_stores}` — reuse the existing permission; a new one would need a team-management UI change. Split view: queue left (oldest first, status filter, `stream/3`), case panel right showing store, host, `records_for/1` (so staff see what the merchant was told), `status_reason`, `verifying_since`. Every mutating `handle_event` re-checks permission against a freshly reloaded user. **Activate** → `request_verification/2`; **Reject** → `revoke/2` with a reason; both audited via `PlatformAudit.log/4`.

**The activate button transitions state only — it never calls Fly.** That is what decouples H from C and D: H lands on `main` with no Fly client in the tree, and a `:verifying` row simply sits there until D exists — invisible to routing, since both plugs match `:active`.

**Tests first** — non-staff and unpermissioned redirected; queue lists only `:custom`, oldest first; filter narrows; activate writes an audit entry; activate on an already-`:verifying` row surfaces an error; reject → `:expired` with reason; permission revoked after mount refuses the next activate; no DB queries in disconnected mount; **decoupling proof: activating issues zero `FlyCertsMock` calls**.

---

## Out of scope (decisions, not oversights)

- **Cart does not survive a host change.** Cookies are host-only (`endpoint.ex:7-15`, no `domain:`) and the cart is session-keyed (`plugs/cart_session.ex:18-27`). Acceptable while the custom domain is the merchant's single advertised address.
- **Customer OAuth is apex-pinned** (`runtime.exs:403`). `auth_tokens.ex:95-140` already has the short-lived exchange-token pattern to bridge it later.
- **Cloudflare for SaaS** — revisit past ~50 domains.
- **Plan gating** — `FeatureFlags.enabled?/2` has zero call sites; wiring the first needs the `starter/pro` (code) vs `Growth` (docs) slug mismatch reconciled first.

**Mentioned, not fixed** (Surgical Changes): missing FK `on_delete` on `store_domains_store_id_fkey`; `StoreAddressLive`'s duplicate-row re-claim; `hooks/resolve_store_from_host.ex` collapsing a suspended store's `:unavailable` into `redirect(to: "/")`, which loops on a non-apex host — custom domains make this reachable more often, so it should be next after this feature.

⚠️ **HSTS on a third party's domain — an explicit decision.** `config/prod.exs:13-25` sets `force_ssl` with `subdomains: true, preload: true`, so every response over `kentekingdom.com` carries an HSTS header the merchant cannot revoke; if they later repoint the domain at a plain-HTTP host it breaks for everyone who visited. Unlike the other three this is a commitment made on someone else's property. Recommendation: **ship as-is** (Fly issues valid certs automatically), but record it in the PR and revisit `preload: true` before the first non-Makola-controlled domain goes live.

---

## Per-slice gate

```bash
mix format --check-formatted
mix credo --strict
mix compile --warnings-as-errors
mix test                      # full suite, not just the slice's files
```

The full suite matters more than usual: A, B and F all touch the hot path of every existing storefront request, and three of the highest-value tests here (A's subdomain regression, B's `:create` default, F's subdomain-primary scope limit) exist purely to prove the subdomain path did not move.

**End-to-end verification** is a real domain on prod: walk `:pending → :verifying → :active`, confirm Fly reads `Ready`, confirm the `wss://` handshake returns 101 on the custom domain **and** still on `makola.io`, and confirm the canonical self-references.
