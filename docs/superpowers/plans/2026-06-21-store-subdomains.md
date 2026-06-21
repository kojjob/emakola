# Store Subdomain Pretty URLs — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Serve storefronts at `tiny-stitches.makola.io/cart` (pretty subdomain in the address bar) while keeping the indexed canonical on `makola.io/s/tiny-stitches`; every store auto-gets a subdomain.

**Architecture:** The serving already works (`StoreDomain.serve_in_place?` + `ResolveStoreByHost` rewrites `path_info`). New work: (1) a `on_store_subdomain?` flag carried request→LiveView, (2) a host-aware `Storefront.Path` helper used by all storefront **navigational** links (canonical/sitemap/OG stay on `SEO.Canonical` apex), (3) auto-provision a `serve_in_place?` primary `StoreDomain` per store. Ship-dark behind `store_subdomain_base`.

**Tech Stack:** Phoenix LiveView, Ash 3.x, Plug, TailwindCSS.

**Spec:** `docs/superpowers/specs/2026-06-21-store-subdomains-design.md`

> Branch fresh from main: `git checkout main && git pull && git checkout -b feature/store-subdomains-impl`. Independent of the open WhatsApp PR (#185).

---

## File Structure

**Create:**
- `lib/emakola_web/storefront/path.ex` — `EmakolaWeb.Storefront.Path.store_path/2` host-aware link helper.
- `lib/mix/tasks/emakola.backfill_store_subdomains.ex` — one-off backfill.
- Tests mirroring each.

**Modify:**
- `lib/emakola_web/plugs/resolve_store_by_host.ex` — set `on_store_subdomain?` in the session when serving a subdomain in place.
- `lib/emakola_web/hooks/resolve_store.ex` — read that session flag → `assign(:on_store_subdomain?, …)`.
- `lib/emakola/stores/resources/store.ex` — after-create change that provisions the `<slug>.<base>` `StoreDomain` (ship-dark; reserved-guarded; updates on slug change).
- ~17 storefront files (LiveViews + components + layouts) — route the 55 internal navigational links through `store_path/2`.
- `docs/PROVIDER_SETUP.md` — activation steps.

---

## Task 1: Carry the `on_store_subdomain?` flag request → LiveView

**Files:**
- Modify: `lib/emakola_web/plugs/resolve_store_by_host.ex`
- Modify: `lib/emakola_web/hooks/resolve_store.ex`
- Test: `test/emakola_web/hooks/resolve_store_subdomain_flag_test.exs`

**First, read both files** to confirm: how `ResolveStoreByHost.call/2` decides `{:serve_in_place, slug}` (it already does), and how `ResolveStore.on_mount/4` builds the socket. The flag default must be `false` everywhere.

- [ ] **Step 1: Write the failing test** — the hook assigns `on_store_subdomain?: true` when the session says so, false otherwise.

```elixir
# test/emakola_web/hooks/resolve_store_subdomain_flag_test.exs
defmodule EmakolaWeb.Hooks.ResolveStoreSubdomainFlagTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    %{store: store}
  end

  test "storefront LiveView assigns on_store_subdomain? from the session flag", %{conn: conn, store: store} do
    conn = Plug.Test.init_test_session(conn, %{"on_store_subdomain?" => true})
    {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}")
    assert :sys.get_state(view.pid).socket.assigns.on_store_subdomain? == true
  end

  test "defaults to false when the flag is absent", %{conn: conn, store: store} do
    {:ok, view, _html} = live(conn, ~p"/s/#{store.slug}")
    assert :sys.get_state(view.pid).socket.assigns.on_store_subdomain? == false
  end
end
```

- [ ] **Step 2: Run** — `mix test test/emakola_web/hooks/resolve_store_subdomain_flag_test.exs` → FAIL (assign missing).

- [ ] **Step 3: Set the flag in the plug.** In `resolve_store_by_host.ex`, in the `{:serve_in_place, slug}` branch (where it rewrites `path_info`), also `Plug.Conn.put_session(conn, :on_store_subdomain?, true)` before rewriting. (Leave the `{:redirect, _}` and pass-through branches alone — absence = false.)

- [ ] **Step 4: Read the flag in the hook.** In `resolve_store.ex` `on_mount(:default, %{"store_slug" => slug}, session, socket)`, add to the success assigns:

```elixir
|> assign(:on_store_subdomain?, Map.get(session, "on_store_subdomain?", false))
```

- [ ] **Step 5: Run** → PASS.

- [ ] **Step 6: Commit** — `git commit -m "feat(subdomains): carry on_store_subdomain? flag request→LiveView"`.

---

## Task 2: Host-aware `Storefront.Path` helper

**Files:**
- Create: `lib/emakola_web/storefront/path.ex`
- Test: `test/emakola_web/storefront/path_test.exs`

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola_web/storefront/path_test.exs
defmodule EmakolaWeb.Storefront.PathTest do
  use ExUnit.Case, async: true
  alias EmakolaWeb.Storefront.Path, as: SP

  test "on the store's own subdomain, drops the /s/:slug prefix" do
    assigns = %{on_store_subdomain?: true, store: %{slug: "tiny-stitches"}}
    assert SP.store_path(assigns, "/cart") == "/cart"
    assert SP.store_path(assigns, "/products/abc") == "/products/abc"
    assert SP.store_path(assigns, "/") == "/"
  end

  test "on the apex (or another host), keeps /s/:slug" do
    assigns = %{on_store_subdomain?: false, store: %{slug: "tiny-stitches"}}
    assert SP.store_path(assigns, "/cart") == "/s/tiny-stitches/cart"
    assert SP.store_path(assigns, "/") == "/s/tiny-stitches"
  end
end
```

- [ ] **Step 2: Run** → FAIL (module undefined).

- [ ] **Step 3: Implement**

```elixir
# lib/emakola_web/storefront/path.ex
defmodule EmakolaWeb.Storefront.Path do
  @moduledoc """
  Host-aware storefront link builder. On a store's own subdomain
  (`tiny-stitches.makola.io`) it drops the `/s/:slug` prefix so links read
  `/cart`; on the apex (`makola.io/s/:slug/...`) it keeps `/s/:slug/cart`.

  Use for the storefront's **navigational** links only. Canonical, sitemap and
  Open Graph URLs must keep using `EmakolaWeb.SEO.Canonical` (always apex
  `/s/:slug`) so SEO authority stays consolidated.

  `assigns` must carry `:on_store_subdomain?` (set by ResolveStore) and `:store`.
  """
  @spec store_path(map(), String.t()) :: String.t()
  def store_path(%{on_store_subdomain?: true}, subpath), do: normalize(subpath)

  def store_path(%{store: %{slug: slug}}, subpath) do
    case normalize(subpath) do
      "/" -> "/s/#{slug}"
      path -> "/s/#{slug}#{path}"
    end
  end

  defp normalize("/" <> _ = p), do: p
  defp normalize(""), do: "/"
  defp normalize(p), do: "/" <> p
end
```

- [ ] **Step 4: Run** → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(subdomains): host-aware Storefront.Path link helper"`.

---

## Task 3: Route storefront navigational links through the helper

**Files (the 55 sites — confirm with the greps):**
- LiveViews in `lib/emakola_web/live/storefront/*.ex`
- Components: `storefront_components.ex` (12), `stores_components.ex` (6), `search_components.ex` (2), `layouts/storefront.html.heex` (7), `layouts/app.html.heex` (2)
- Test: `test/emakola_web/live/storefront/subdomain_links_test.exs`

**Transformation (apply uniformly):** replace each storefront **navigational** link of the form `~p"/s/#{@store.slug}/<subpath>"` (and `"/s/#{store.slug}/<subpath>"` string interpolations) with `EmakolaWeb.Storefront.Path.store_path(assigns, "/<subpath>")`. Import the helper (`import EmakolaWeb.Storefront.Path` in each module; for `.heex` layouts/components, the helper is available via the assigns-passing module — call `Storefront.Path.store_path(assigns, ...)` fully-qualified). **Do NOT touch** canonical/sitemap/OG (`SEO.Canonical.*`) or cross-store links (e.g. the platform `/stores` listing linking to other stores — those must stay `/s/:slug`). `account_downloads_live` renders a download-controller URL that is NOT a LiveView nav link — keep it `/s/:slug/downloads/...` (controller route, not subdomain-rewritten) unless it's served on the subdomain too; verify.

- [ ] **Step 1: Enumerate the sites** — `grep -rnE '~p"/s/#\{|/s/#\{' lib/emakola_web/live/storefront lib/emakola_web/components`. For each hit, decide: navigational-within-this-store (→ helper) or cross-store/canonical/controller (→ leave). Keep a short list of the "left alone" ones in the commit message.

- [ ] **Step 2: Write the failing test** — render a storefront page with the subdomain flag set and assert links are prefix-free; without it, assert `/s/:slug` links.

```elixir
# test/emakola_web/live/storefront/subdomain_links_test.exs
defmodule EmakolaWeb.Storefront.SubdomainLinksTest do
  use EmakolaWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  setup do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    %{store: store}
  end

  test "on the subdomain, nav links omit /s/:slug", %{conn: conn, store: store} do
    conn = Plug.Test.init_test_session(conn, %{"on_store_subdomain?" => true})
    {:ok, _v, html} = live(conn, ~p"/s/#{store.slug}")
    assert html =~ ~s(href="/cart")
    refute html =~ ~s(href="/s/#{store.slug}/cart")
  end

  test "on the apex, nav links keep /s/:slug", %{conn: conn, store: store} do
    {:ok, _v, html} = live(conn, ~p"/s/#{store.slug}")
    assert html =~ ~s(href="/s/#{store.slug}/cart")
  end
end
```

- [ ] **Step 3: Run** → FAIL (links still hardcoded).

- [ ] **Step 4: Apply the transformation** across the enumerated sites (helper import + `store_path(assigns, "/...")`). Work module-by-module; after each, `mix compile` to catch arity/assigns issues.

- [ ] **Step 5: Run** the new test + the full storefront suite (`mix test test/emakola_web/live/storefront test/emakola_web/components`) → all PASS (no apex regressions).

- [ ] **Step 6: Commit** — `git commit -m "feat(subdomains): route storefront nav links through Storefront.Path"`.

---

## Task 4: Auto-provision a subdomain `StoreDomain` per store

**Files:**
- Create: `lib/emakola/stores/changes/provision_subdomain.ex`
- Modify: `lib/emakola/stores/resources/store.ex` (attach the change on create + slug-changing updates)
- Test: `test/emakola/stores/provision_subdomain_test.exs`

**Read first:** `store.ex` create/update actions + how slug is set, and `StoreDomain`'s create action + `ValidStoreHost`.

- [ ] **Step 1: Write the failing test**

```elixir
# test/emakola/stores/provision_subdomain_test.exs
defmodule Emakola.Stores.ProvisionSubdomainTest do
  use Emakola.DataCase, async: false  # toggles :store_subdomain_base

  setup do
    prev = Application.get_env(:emakola, :store_subdomain_base)
    Application.put_env(:emakola, :store_subdomain_base, "makola.io")
    on_exit(fn ->
      if prev, do: Application.put_env(:emakola, :store_subdomain_base, prev),
      else: Application.delete_env(:emakola, :store_subdomain_base)
    end)
    :ok
  end

  test "creating a store provisions a serve-in-place primary subdomain" do
    {_m, store} = Emakola.Factory.create_merchant_with_store!()

    domain =
      Emakola.Stores.StoreDomain
      |> Ash.read!(authorize?: false)
      |> Enum.find(&(&1.store_id == store.id))

    assert domain.host == "#{store.slug}.makola.io"
    assert domain.serve_in_place? == true
    assert domain.primary? == true
  end

  test "no subdomain is provisioned when the base is unset (ship-dark)" do
    Application.delete_env(:emakola, :store_subdomain_base)
    {_m, store} = Emakola.Factory.create_merchant_with_store!()
    refute Emakola.Stores.StoreDomain |> Ash.read!(authorize?: false) |> Enum.any?(&(&1.store_id == store.id))
  end
end
```

- [ ] **Step 2: Run** → FAIL (no provisioning).

- [ ] **Step 3: Implement the change** — an after-action that, when `store_subdomain_base` is set, upserts a primary serve-in-place `StoreDomain` for `<slug>.<base>` (skip on reserved slug via `ValidStoreHost`/the create validation; rescue + log so a domain failure never breaks store creation, per the welcome-email lesson):

```elixir
# lib/emakola/stores/changes/provision_subdomain.ex
defmodule Emakola.Stores.Changes.ProvisionSubdomain do
  @moduledoc "After-action: provision a serve-in-place primary <slug>.<base> StoreDomain (ship-dark)."
  use Ash.Resource.Change
  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _cs, store ->
      provision(store)
      {:ok, store}
    end)
  end

  defp provision(store) do
    case Application.get_env(:emakola, :store_subdomain_base) do
      base when is_binary(base) and base != "" ->
        Emakola.Stores.StoreDomain
        |> Ash.Changeset.for_create(:create, %{
          store_id: store.id,
          host: "#{store.slug}.#{base}",
          type: :subdomain,
          serve_in_place?: true,
          primary?: true,
          status: :active
        })
        |> Ash.create(authorize?: false)
        |> case do
          {:ok, _} -> :ok
          {:error, reason} -> Logger.warning("[subdomains] provision skipped for #{store.slug}: #{inspect(reason)}")
        end

      _ ->
        :ok
    end
  rescue
    e -> Logger.error("[subdomains] provision raised for #{store.slug}: #{Exception.message(e)}")
  end
end
```

Attach in `store.ex` `changes do` block: `change Emakola.Stores.Changes.ProvisionSubdomain, on: [:create]`. (Confirm the `StoreDomain.create` action accepts those fields; adjust to the real action name/accepts.)

- [ ] **Step 4: Run** → PASS. Also add/extend a test for slug change updating the primary host (if store has a slug-update action — re-provision/realias).

- [ ] **Step 5: Commit** — `git commit -m "feat(subdomains): auto-provision serve-in-place subdomain on store create"`.

---

## Task 5: Backfill mix task for existing stores

**Files:**
- Create: `lib/mix/tasks/emakola.backfill_store_subdomains.ex`
- Test: `test/mix/tasks/backfill_store_subdomains_test.exs`

- [ ] **Step 1: Write the failing test** — seed 2 stores (no domains), run the task, assert each gets a primary serve-in-place subdomain; running twice is idempotent (no duplicates).
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** `mix emakola.backfill_store_subdomains` — `Mix.Task` that boots the app, reads all stores lacking a primary subdomain, and provisions one each via the same `StoreDomain.create` (skip reserved slugs; idempotent via the host unique constraint / a "primary exists?" check). Guard on `store_subdomain_base` being set.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(subdomains): backfill mix task for existing stores"`.

---

## Task 6: Verification + activation docs

- [ ] **Step 1:** Full `mix test` → green (the 55-site rewiring is the regression risk — confirm apex storefront tests still pass).
- [ ] **Step 2:** `mix format --check-formatted` + `mix credo --strict` (touched files) + `mix compile --warnings-as-errors` (no new warnings) clean.
- [ ] **Step 3:** Manually confirm canonical: a storefront page emits `<link rel=canonical href="https://makola.io/s/:slug...">` regardless of the `on_store_subdomain?` flag (it routes through `SEO.Canonical`, untouched).
- [ ] **Step 4:** Add a "Store subdomains" section to `docs/PROVIDER_SETUP.md`: `fly certs add '*.makola.io'` + Namecheap wildcard `*.makola.io` A/AAAA → Fly IPs → `fly secrets set STORE_SUBDOMAIN_BASE=makola.io` → `mix emakola.backfill_store_subdomains`. Note check_origin already wildcards `*.makola.io`.
- [ ] **Step 5: Commit** — `git commit -m "docs(subdomains): activation steps"`. Push + open PR → main.

---

## Self-Review

**Spec coverage:** serve-in-place (existing + Task 1 flag) · host-aware links (Tasks 2–3) · canonical-stays-subfolder (untouched `SEO.Canonical`, verified Task 6) · auto-provision every store (Task 4) · backfill (Task 5) · reserved-word guard (reuse `ValidStoreHost`, Task 4) · ship-dark `store_subdomain_base` (Tasks 4–5) · activation ops (Task 6). All mapped.

**Placeholder scan:** Task 3 describes a uniform transformation across 55 sites rather than 55 code blocks (the skill permits describing a repeated pattern once + listing representative paths) — each non-trivial helper/change/task shows full code.

**Type consistency:** `store_path(assigns, subpath)` signature is consistent (Tasks 2, 3); `on_store_subdomain?` key consistent (Tasks 1, 2, 3); `StoreDomain.create` fields (`host/type/serve_in_place?/primary?/status`) consistent (Tasks 4, 5).

**Pre-implementation checks (do first):** confirm the real `StoreDomain` create action name + accepted fields; confirm `store.ex` has a slug-changing update action (for the slug-change re-provision in Task 4 step 4); confirm `.heex` layouts can call `EmakolaWeb.Storefront.Path.store_path/2` (assigns available).
