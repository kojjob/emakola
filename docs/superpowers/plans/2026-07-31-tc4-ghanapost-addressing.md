# TC-4 GhanaPost Addressing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optional GhanaPost digital-address code (normalized + format-validated) and a nudged landmark field on every surface that collects or renders delivery addresses — riders navigate by landmarks; the code is a bonus.

**Architecture:** One pure module (`Emakola.GhanaDigitalAddress`) + one shared function component (`EmakolaWeb.AddressComponents.gh_address_fields/1`) adopted by the two live buyer surfaces (shared checkout renderer, pay-link page); the values ride the existing schemaless `shipping_address` maps (zero order-side migration); `Customers.Address` and `Store` gain the two columns for default-address reuse and pickup-origin parity; admin order show renders both keys.

**Tech Stack:** Elixir/Phoenix 1.8 LiveView, Ash 3.x. Smallest build of the series.

**Spec:** `docs/superpowers/specs/2026-07-30-ghanapost-addressing-design.md`.

## Surface reality (recon-verified deviations from the spec — carry to PR body)

- **No customer address-book UI exists** (`Customers.Address` has zero web-layer usage). The resource gains the attributes (checkout's default-address reuse path stores/serves them) but there is no form to extend. Spec's "address book" surface → resource-only.
- **The delivery email renders no address** (it's a thank-you note). The spec's own surgical rule — fields appear ONLY where addresses already render — excludes it. Skipped.
- **`Admin.StoreAddressLive` is the WEB-address (subdomain) panel**, not physical address. The store's physical address lives as flat attributes on `Store` edited in the settings page — that's where the two new store fields go.
- **The susu page (unmerged PR #367) adopts the shared component as a follow-up after that PR lands** — no cross-branch dependency.

## Global Constraints

- Both fields OPTIONAL everywhere — blank never blocks anything; the landmark carries the placeholder `e.g. behind Achimota Melcom, blue gate` and, on delivery-collecting flows, the hint `Helps the rider find you faster`.
- Normalization: trim, upcase, spaces/mixed separators → hyphens; separator-less input re-hyphenated deterministically (2 leading letters, last 4 digits, middle = remainder: `GA1838164` → `GA-183-8164`). Validation `^[A-Z]{2}-\d{3,4}-\d{4}$` ONLY when present; empty/nil always valid; invalid → friendly message, never a crash. NO GhanaPost API calls, NO region-letter checking (v1 decisions).
- Storefront LiveViews: no catch-all `handle_event` — the new inputs ride EXISTING form submits (no new events anywhere).
- `mix ash.codegen` broken repo-wide — hand-write or `ash_postgres.generate_migrations --domains` + trim; snapshots synced; both envs.
- `%{__struct__: __MODULE__}` plain-map patterns if any struct matching is added to Ash resources (the Dockerfile-1.18.3 release-image class — no `%__MODULE__{`).
- TDD RED/GREEN; format + credo per commit; Result: lines only.

**Precedent files:** `lib/emakola/payments/platform_fee.ex` (pure-module shape + test style) · `lib/emakola/themes/default_renderers/checkout.ex:263-295` (the address/region inputs) · `lib/emakola_web/live/storefront/pay_link_live.ex:41,283-287` (buyer map + shipping_address) · `lib/emakola_web/live/admin/order_live/show.ex:455-476,714` (`address_display/1`) · TC-2 Task 2's Store-attribute + settings-toggle pattern.

---

### Task 1: `Emakola.GhanaDigitalAddress` + shared component

**Files:**
- Create: `lib/emakola/ghana_digital_address.ex`, `lib/emakola_web/components/address_components.ex`
- Test: `test/emakola/ghana_digital_address_test.exs`, `test/emakola_web/components/address_components_test.exs`

**Interfaces (produces):**
- `GhanaDigitalAddress.normalize/1` — nil → nil; binary → trimmed/upcased/re-hyphenated per the Global Constraints rules (returns the best-effort normalized string even when invalid — validation is separate).
- `GhanaDigitalAddress.valid?/1` — nil/"" → true; otherwise regex on the NORMALIZED form.
- `AddressComponents.gh_address_fields/1` — function component, attrs: `digital_address :string default ""`, `landmark :string default ""`, `field_prefix :string` (e.g. `"buyer"` renders `name="buyer[digital_address]"`; `""` renders bare `name="digital_address"` for the checkout renderer's flat form), `show_hint :boolean default true`. Renders the two labeled optional inputs (Tailwind classes matching the checkout renderer's input idiom), landmark placeholder + hint per constraints. NO events of its own.

- [ ] **Step 1: failing tests** — normalization table (each Global Constraints case: `ga 183 8164`, `GA-183-8164`, `ga1838164`, `GA—183—8164` em-dash → hyphen, whitespace padding, separator-less 2-letters+8-digits `GA18381649` (last 4 split off, middle = the remaining 4 → `GA-1838-1649`, valid per `\d{3,4}`), separator-less 2+7 `GA1838164` → `GA-183-8164`, nil, ""); valid? table (valid 3-digit + 4-digit middles, too-short, letters-in-digits, empty ok); component render test (both prefixes, hint on/off, placeholder present).
- [ ] **Step 2: implement + green** → commit `feat(orders): GhanaPost digital-address module and shared address fieldset`

---

### Task 2: Checkout surfaces — shared renderer + pay-link page

**Files:**
- Modify: `lib/emakola/themes/default_renderers/checkout.ex` (insert `gh_address_fields` after the address textarea, flat prefix), `lib/emakola_web/live/storefront/checkout_live.ex` (thread params → shipping_address map + validate), `lib/emakola_web/live/storefront/pay_link_live.ex` (buyer map + fields under collect_delivery + shipping_address/2 + validate)
- Test: extend `test/emakola_web/live/storefront/checkout_live_test.exs` + `pay_link_live_test.exs`

**Interfaces (produces):**
- Both flows: on submit, normalize the digital address; when invalid → the form re-renders with the friendly message `Check the digital address — it looks like GA-183-8164` and NO order is created; when valid/blank → `shipping_address` map gains `"digital_address"` (normalized) and `"landmark"` keys (blank values → keys omitted, keep maps clean).
- Verify-first: how checkout_live reads its flat form params (the `name="address"`/`name="region"` fields — find the submit handler's params shape and mirror for the two new flat fields) and how it builds the shipping_address map for `checkout!` — cite in the report.
- The renderer imports/uses the component (verify the themes' render context can call `EmakolaWeb.AddressComponents` — default_renderers are HEEX-in-Elixir modules; confirm an import/alias works like their other component usage; if they use no components today, call the component via its full module per Phoenix.Component conventions and note it).

- [ ] **Step 1: failing tests** — checkout: valid messy code → order's shipping_address carries normalized code + landmark; blank both → keys absent, order fine; invalid code → friendly error, zero orders; pay-link (collect_delivery true): same trio; collect_delivery false → fields not rendered.
- [ ] **Step 2: implement + green** → commit `feat(web): GhanaPost + landmark fields on checkout and pay-link flows`

---

### Task 3: `Customers.Address` + `Store` columns

**Files:**
- Modify: `lib/emakola/customers/resources/address.ex`, `lib/emakola/stores/resources/store.ex`, the merchant settings LiveView's physical-address section (locate the form editing store.address/city/region — TC-2 Task 2's report cites the settings action; follow it)
- Create: migration (both tables)
- Test: extend the resources' tests + settings LiveView test

**Interfaces (produces):**
- `Address.digital_address`/`landmark` (:string nil, accepted on create/update; digital_address normalized+validated via a change calling GhanaDigitalAddress — invalid → validation error).
- `Store.digital_address`/`landmark` — same treatment, accepted on the settings update action; two inputs added to the settings page's address section via `gh_address_fields` (flat or form prefix per that form's idiom).

- [ ] **Step 1: failing tests** — Address + Store persist normalized values, reject invalid, accept blank; settings page renders + saves the fields.
- [ ] **Step 2: implement + migration (both envs, snapshots) + green** → commit `feat(stores): GhanaPost + landmark on customer addresses and store profile`

---

### Task 4: Admin order rendering + gate

**Files:**
- Modify: `lib/emakola_web/live/admin/order_live/show.ex` (`address_display/1` renders `digital_address` — copyable via the existing copy-to-clipboard listener from TC-1 — and `landmark` when present)
- Test: extend admin order show tests; guard: order WITHOUT the keys renders unchanged (legacy maps).

- [ ] **Step 1: failing tests** — order with both keys shows them (copy button on the code); legacy order without keys byte-identical render.
- [ ] **Step 2: implement + green** → commit `feat(web): render GhanaPost address and landmark on admin orders`
- [ ] **Step 3: full gate** — format + credo + full `mix test` (Result: 0 failures) → rebase origin/main → re-run.
- [ ] **Step 4:** TODO.md PLANNED + ACTION_ROADMAP TC-4 flips → commit `docs: mark TC-4 ghanapost addressing implemented`. Push/PR EXCLUDED (controller runs the final review first).
