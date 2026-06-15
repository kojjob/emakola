# Platform Merchants — Directory + Drill-down

**Date:** 2026-06-15
**Status:** Approved design, pending implementation plan
**Scope:** Sub-project 2 of 3 in the platform-admin redesign (Settings ✅ → **Merchants** → Billing).

## Problem

The platform sidebar already links to `/platform/merchants` (a real `sidebar_link`, not a
"Soon" stub), but **no route or page exists** — the link 404s. The project owner needs a
real directory of every merchant on the platform, with a drill-down into each merchant's
profile and the stores they belong to.

Read-only. **No new DB models.**

## Decisions (locked with owner, 2026-06-15)

| Decision | Choice |
|---|---|
| Page shape | **Single LiveView** `Platform.MerchantLive.Index` at `/platform/merchants` |
| Drill-down | **Slide-over drawer** (`<.modal kind={:slide_over}>`), NOT a separate route |
| Drawer rendering | **Always rendered, nil-safe** (avoid the `:if`-before-`show_modal` race seen in Settings) |
| Interactivity | **Read-only** — no suspend / impersonate / resend-confirmation |
| Accent / conventions | Blue platform accent; `authorize?: false`; plain patterns; mirrors `StoreLive.Index` + `Admin.CustomerLive` |

## Background — data model (already exists)

`Emakola.Accounts.Merchant`: `email` (ci_string), `name`, `phone`, `business_name`,
`avatar_url`, `confirmed_at`, `preferences`, `inserted_at`. Read actions are policy-bypassed
(open), so `authorize?: false` reads work.

Relationships: `has_many :store_memberships` and `many_to_many :stores` through
`StoreMembership`. **Role lives on the join** (`StoreMembership.role`, one_of
`:owner | :admin | :staff`), NOT on `stores` — so per-store role requires loading
`store_memberships: [:store]`.

`Store` has `name`, `slug`, `active`. There is no merchant `list_for_admin` action yet;
`Store` has one to mirror (`store.ex:286`).

## 1. Domain layer

### Merchant read action (`lib/emakola/accounts/resources/merchant.ex`)
Add a `read :list_for_admin`, mirroring `Store.list_for_admin`:

```elixir
read :list_for_admin do
  argument(:search, :string, default: "")

  filter(
    expr(
      is_nil(^arg(:search)) or ^arg(:search) == "" or
        ilike(name, ^arg(:search)) or ilike(email, ^arg(:search)) or
        ilike(business_name, ^arg(:search)) or ilike(phone, ^arg(:search))
    )
  )

  prepare(build(sort: [inserted_at: :desc], load: [:stores]))
end
```

### Accounts domain interfaces (`lib/emakola/accounts/accounts.ex`)
Under the existing `resource Emakola.Accounts.Merchant do` block, add:

```elixir
define(:list_merchants_for_admin, action: :list_for_admin, args: [:search])
define(:get_merchant, action: :read, get_by: [:id])
```

The drawer loads roles separately via `Ash.get!(Merchant, id, load: [store_memberships: [:store]], authorize?: false)` (or the `get_merchant` interface with a `load:` opt). Keep the role-bearing load in the LiveView, not baked into `list_for_admin` (the list only needs `:stores` for a count).

## 2. Routing & navigation

**Router** (`lib/emakola_web/router.ex`) — inside the existing `:platform` live_session:

```elixir
live "/platform/merchants", Platform.MerchantLive.Index
```

**Layout** — no change. The `Merchants` `sidebar_link` already exists
(`platform.html.heex`); it activates on `@active_nav == :merchants`.

## 3. LiveView — `EmakolaWeb.Platform.MerchantLive.Index`

File: `lib/emakola_web/live/platform/merchant_live/index.ex` (matches the
`platform/store_live/index.ex` directory convention).

### Assigns
- `:page_title` → "Merchants"; `:active_nav` → `:merchants`
- `:search` → "", `:filter` → `:all | :confirmed | :unconfirmed`
- `:all_merchants` → full list (source for filter + stats; each loaded with `:stores`)
- `:merchants` → **stream** of the filtered/sorted view
- `:stats` → `%{total, confirmed, with_store, new_30d}` (from `:all_merchants`)
- `:filtered_count` → integer (for empty-state handling alongside `phx-update="stream"`)
- `:selected_merchant` → nil | merchant loaded with `store_memberships: [:store]` (drives the drawer)

### Events
| Event | Behavior |
|---|---|
| `"search"` (`%{"search" => q}`) | assign, re-stream filtered |
| `"filter"` (`%{"filter" => f}`) | `parse_filter/1` (allowlist → `:all/:confirmed/:unconfirmed`), re-stream |
| `"select_merchant"` (`%{"id" => id}`) | load merchant + memberships+stores, assign `:selected_merchant` (drawer opened client-side via `show_modal`) |

Data load: `list_merchants_for_admin(search, authorize?: false)`, in-memory filter by
confirmed status, sort `inserted_at: :desc`. Stats from the unfiltered list. Mutation-free
page, so a `rescue`-guarded load like `StoreLive` is enough (no streams churn beyond
search/filter resets).

### Filter / stats helpers
- `confirmed?(m) = not is_nil(m.confirmed_at)`
- `new_30d`: `inserted_at` within 30 days of now (compute `cutoff` in the LiveView; do not call `Date`/`DateTime.utc_now` at module load — call inside the function).
- `parse_filter("confirmed") -> :confirmed`, `"unconfirmed" -> :unconfirmed`, `_ -> :all`.

## 4. UI anatomy

Container mirrors siblings: `<div class="p-6 lg:p-8 max-w-7xl mx-auto">`.

1. **Header** — "Merchants" + subtitle "Everyone building on Emakola ({total})".
2. **Stat strip** — 4 cards (reuse the local `stat/1` style from `SettingsLive`):
   Total · Confirmed · With a store · New (30d).
3. **Toolbar** — search input (name/email/business/phone) + filter chips
   (All / Confirmed / Unconfirmed).
4. **Table** (`phx-update="stream"`, `id="merchants"`), columns:
   - **Merchant**: avatar circle (initials from name/email) + name + email.
   - **Business**: `business_name` or muted "—".
   - **Stores**: count badge (e.g. "2 stores"); "—" if none.
   - **Status**: Confirmed (green) / Pending (amber) pill.
   - **Joined**: `Calendar.strftime(inserted_at, "%b %d, %Y")`.
   - Whole row: `phx-click={JS.push("select_merchant", value: %{id}) |> show_modal("merchant-drawer")}` (cursor-pointer).
5. **Empty states** — "No merchants yet" (total 0) / "No merchants match your filters".
6. **Slide-over drawer** — `<.modal id="merchant-drawer" kind={:slide_over} title="Merchant">`,
   **always rendered, nil-safe** on `@selected_merchant`:
   - Profile header: large avatar, name, email, phone, business, Confirmed/Pending badge, joined date.
   - Stat row: store count, role summary.
   - **Stores list**: each membership → store name + `slug` + **role badge**
     (owner=blue, admin=violet, staff=slate) + storefront link (`/s/{slug}`, `target=_blank`).
     Empty: "This merchant has no stores yet."

Design tokens: blue accent, `rounded-xl` cards, `border-slate-200`, mobile-first.

## 5. Testing (TDD — first)

`test/emakola_web/live/platform/merchant_live/index_test.exs`. Reuse the platform
test-auth helper (`Factory.create_platform_admin!` + `user_to_subject` token — see the
Settings test). Factory: a `create_merchant!`/`create_merchant_with_store!` already exists.
Cases:

1. **Access**: platform admin loads; non-admin merchant redirected to "/".
2. **Renders** all merchants (name + email).
3. **Stat strip** counts correct (seed: 3 merchants, 2 confirmed, 1 with a store).
4. **Search** by name and by email narrows the list.
5. **Filter** Unconfirmed shows only merchants with `confirmed_at == nil`.
6. **Store count** column shows the right count for a merchant with a store.
7. **Drill-down**: `select_merchant` loads the merchant; drawer shows the merchant's
   name and their store name + role badge.
8. **Empty state** when no merchants.

Also add a domain test for `list_merchants_for_admin/1` (returns all; search filters by
name/email) in `test/emakola/accounts/` if not covered.

Mocking: none (DB-backed).

## 6. Out of scope
- Any merchant mutation (suspend, impersonate, resend confirmation, role edits).
- Pagination (merchant counts are small at launch; revisit if needed — `list_for_admin`
  can gain offset pagination later like `Store.list_featured`).
- Merchants↔orders/GMV rollups (belongs with Billing).

## Success criteria
- `/platform/merchants` loads for the owner (no 404), lists real merchants, search +
  filter work, row opens a drawer with the merchant's stores and roles.
- `mix test` green incl. new files; `mix format --check-formatted` + `mix credo --strict` clean.
- Visual language matches the platform shell + the Settings page.
