# Platform Settings — Feature Flags Manager

**Date:** 2026-06-14
**Status:** Approved design, pending implementation plan
**Scope:** Sub-project 1 of 3 in the platform-admin redesign.
Later sub-projects (own spec + plan each, out of scope here):
**2. Merchants** (rich directory + drill-down over `Accounts.Merchant`),
**3. Billing** (a new `Emakola.Billing` subscription domain).

## Problem

The platform admin shell (`/platform`, project-owner only) already advertises three
destinations in its sidebar — **Merchants**, **Billing**, **Settings** — but only
Dashboard and Stores are real:

- The **Settings** nav item is a disabled `opacity-50 cursor-not-allowed` stub badged
  "Soon" (`platform.html.heex:150-178`). There is no route, no LiveView, no page.

Meanwhile a fully-functional `FeatureFlags` domain already exists with no admin UI —
flags can only be created/toggled from `iex`. The project owner needs a real,
persisted control surface for runtime feature flags, presented to the same
production-grade standard as the rest of the platform admin.

This sub-project delivers that page. **No new database models.**

## Decisions (locked with product owner, 2026-06-14)

| Decision | Choice |
|---|---|
| What "Settings" contains | **Feature-flag management only** — no new platform-settings model |
| List UI | **Card grid + centered modal** (Approach B) |
| List rendering | **Phoenix streams** (`stream(:flags, …)`) — in-place patch on toggle/delete |
| Modal state | **`Phoenix.LiveView.JS` show/hide**, never CSS `:checked` (project lesson) |
| Accent color | **Blue** — the platform variant's accent (layout uses blue, not merchant emerald) |
| `required_plan` input | **Constrained select**: `None / free / starter / pro / enterprise` |
| Authorization | `authorize?: false` in the LiveView (page already gated by `RequirePlatformAdmin`), matching `StoreLive.Index` precedent |

## Background — what already exists

`Emakola.FeatureFlags.FeatureFlag` (`lib/emakola/feature_flags/resources/feature_flag.ex`):

| Attribute | Type | Notes |
|---|---|---|
| `key` | string, required, unique | immutable identity, e.g. `"new_checkout"` |
| `name` | string, required | human label |
| `description` | string (≤1000) | optional |
| `enabled` | boolean, default `true` | |
| `required_plan` | string (≤255) | gates by plan; **only** `free/starter/pro/enterprise` understood by the evaluator |
| `metadata` | map, default `%{}` | not surfaced in this UI |

Resource actions: `read`, `create`, `update` (accepts everything except `key`),
`toggle` (`require_atomic?(false)`, flips `enabled`), `destroy`.

Domain (`lib/emakola/feature_flags/feature_flags.ex`) currently defines:
`create_flag`, `list_flags`, `get_flag`, `get_flag_by_key`, plus `enabled?/2`.

> **Gotcha captured in design:** `required_plan` is a free string, but `enabled?/2`
> only recognizes the four-tier hierarchy. Any other value makes the flag evaluate
> to *deny-all* silently. The form's constrained select prevents persisting an
> unrecognized plan.

## 1. Domain layer — add thin code interfaces

In `lib/emakola/feature_flags/feature_flags.ex`, add defines for the actions the UI
needs (resource actions already exist; we only expose them):

```elixir
define(:update_flag, action: :update)
define(:toggle_flag, action: :toggle)
define(:destroy_flag, action: :destroy)
```

Keeps the LiveView thin and consistent with how `StoreLive.Index` calls
`Emakola.Stores.update_store_directory_meta`.

## 2. Routing & navigation

**Router** (`lib/emakola_web/router.ex`) — inside the existing `:platform`
`live_session` (already on-mounts `RequirePlatformAdmin`):

```elixir
live "/platform/settings", Platform.SettingsLive
```

**Layout** (`lib/emakola_web/components/layouts/platform.html.heex`) — replace the
disabled Settings stub (lines ~150-178) with a live link, reusing the existing
`sidebar_link` component (it already ships a `"gear"` icon):

```heex
<.sidebar_link
  href="/platform/settings"
  title="Settings"
  icon="gear"
  active={@active_nav == :settings}
/>
```

The `Billing` stub stays "Soon" (sub-project 3).

## 3. LiveView — `EmakolaWeb.Platform.SettingsLive`

File: `lib/emakola_web/live/platform/settings_live.ex` (single module, function
components inline — matches `DashboardLive`/`StoreLive.Index` convention).

### State (assigns)
- `:page_title` → "Settings"
- `:active_nav` → `:settings`
- `:search` → string, default `""`
- `:filter` → one of `:all | :enabled | :disabled`, default `:all`
- `:all_flags` → plain list of every `FeatureFlag` (source of truth for filtering + stats; reloaded after each mutation)
- `:flags` → **stream** of the *filtered/sorted* view derived from `:all_flags`
- `:stats` → `%{total, enabled, gated, disabled}` (derived from `:all_flags`, never the filtered view)
- `:form_action` → `nil | :new | :edit` (drives the modal)
- `:form` → `AshPhoenix.Form` for create/edit (nil when modal closed)

### Data loading
- `list_flags(authorize?: false)`, sorted `name: :asc` → `:all_flags`. Each mutation
  reloads `:all_flags`, recomputes `:stats`, and re-streams the filtered view (or
  `stream_insert`/`stream_delete` the single affected card for toggle/delete).
- Search filters on `name`/`key` (case-insensitive, in-memory — flag counts are small;
  mirrors `StoreLive` simplicity). Filter chip narrows by `enabled`.
- Stats computed from the unfiltered list so the strip is stable while searching.

### Events
| Event | Handler behavior |
|---|---|
| `"search"` | assign query, re-stream filtered flags |
| `"filter"` (`%{"filter" => f}`) | set `:filter`, re-stream |
| `"new"` | build empty `AshPhoenix.Form` for `:create`, set `form_action: :new`, JS opens modal |
| `"edit"` (`%{"id" => id}`) | load flag, build `:update` form, `form_action: :edit`, open modal |
| `"validate"` | `AshPhoenix.Form.validate/2` |
| `"save"` | submit form; on success `stream_insert` the flag, recompute stats, close modal, flash; on error re-assign form with errors |
| `"toggle"` (`%{"id" => id}`) | `toggle_flag(flag, authorize?: false)`; `stream_insert` updated card, recompute stats |
| `"delete"` (`%{"id" => id}`) | `destroy_flag`; `stream_delete`, recompute stats, flash. Guarded by a JS confirm. |

All mutations `put_flash` success/error and never crash the page (rescue/`case` like
existing platform LiVs).

## 4. UI anatomy (Approach B)

Container mirrors siblings: `<div class="p-6 lg:p-8 max-w-7xl mx-auto">`.

1. **Header** — `h1` "Settings", subtitle "Platform feature flags ({n} total)", and a
   primary **New flag** button (`bg-blue-600 hover:bg-blue-700 rounded-xl`, plus icon).
2. **Stat strip** — 4 metric cards (reuse the `metric_card` pattern from `DashboardLive`,
   blue/emerald/amber/slate): Total · Enabled · Plan-gated · Disabled.
3. **Toolbar** — search input (same styling as `StoreLive` search) + filter chips
   (All / Enabled / Disabled) with active chip in blue.
4. **Card grid** — `grid grid-cols-1 sm:grid-cols-2 xl:grid-cols-3 gap-4`,
   `phx-update="stream"`. Each card `id={"flag-#{id}"}`, `rounded-xl border bg-white p-5`:
   - **Top**: flag `name` (font-semibold) + a **toggle switch** (button styled as a
     pill track + knob, blue when on, slate when off; `phx-click="toggle"`).
   - **Meta row**: mono `key` chip (`bg-slate-100 text-slate-600 font-mono`) +
     `required_plan` badge (blue if set, hidden/"All plans" if nil).
   - **Description**: `line-clamp-2 text-sm text-slate-500` (or muted "No description").
   - **Footer**: "Updated {strftime}" left; **Edit** + **Delete** text actions right.
   - **Disabled state**: card gets `opacity-70` + a left `border-l-4 border-slate-300`;
     enabled cards `border-l-4 border-blue-500`.
5. **Empty state** — when zero flags total: centered icon + "No feature flags yet" +
   New-flag CTA. When zero *matches* (search/filter): "No flags match your filters".
6. **Modal** (`fixed inset-0 z-50`, backdrop `bg-black/50`, centered card
   `rounded-2xl`): title "New feature flag" / "Edit {name}". Fields via `<.form>`:
   - `key` — text; **read-only/disabled when editing** (immutable identity).
   - `name` — text, required.
   - `description` — textarea.
   - `enabled` — checkbox/switch.
   - `required_plan` — `<select>`: `None` (→ `nil`) / free / starter / pro / enterprise.
   - Footer: Cancel (closes via `JS.hide`) + Save (`bg-blue-600`).
   Inline field errors from the `AshPhoenix.Form`.

Design tokens follow the platform shell: blue accent, `rounded-xl`/`rounded-2xl`,
`border-slate-200`, white cards, mobile-first responsive grid.

## 5. Testing (TDD — written first)

`test/emakola_web/live/platform/settings_live_test.exs`. Use the existing platform
auth test helper (same setup `StoreLive`/`DashboardLive` tests use — log in a
platform-admin merchant). Cases:

1. **Renders** the page with all existing flags' names + keys.
2. **Stat strip** shows correct counts (seed 3 flags: 2 enabled incl. 1 gated, 1 disabled).
3. **Toggle** flips a flag — assert DB `enabled` changed and the card reflects it.
4. **Search** by name and by key narrows the grid.
5. **Filter** chip (Disabled) shows only disabled flags.
6. **Create** via modal persists a new flag (valid params) and it appears in the grid.
7. **Create validation** — blank `name` / duplicate `key` shows form errors, no insert.
8. **Edit** updates name/description/required_plan; `key` field is disabled in the form.
9. **Delete** removes the flag from DB and grid.
10. **required_plan select** only offers the four valid tiers + None.
11. **Empty state** renders when no flags exist.
12. **Authorization** — a non-platform-admin is redirected (inherited from
    `RequirePlatformAdmin`; one guard test).

Mocking: none needed (pure DB-backed domain).

## 6. Out of scope

- Any new platform-settings model (general config, support email, etc.).
- `metadata` editing.
- Per-store / per-org flag targeting UI (the evaluator supports plan gating only today).
- Merchants and Billing pages (separate sub-projects).

## Success criteria

- `mix test` green, including the new LiveView test file (≥90% coverage of new code).
- `mix format --check-formatted` and `mix credo --strict` clean.
- Navigating to `/platform/settings` as the owner shows real flags; toggling, creating,
  editing, and deleting all persist and reflect immediately.
- The Settings sidebar item is active (no longer a "Soon" stub); Billing remains "Soon".
- Visual language matches the platform shell (blue accent, rounded cards, responsive).
