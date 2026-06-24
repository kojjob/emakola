# Merchant Onboarding Health Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A platform page showing per-store onboarding-milestone completion plus an aggregate funnel, so the owner can spot stuck merchants and activation drop-off.

**Architecture:** A read-only service module (`Emakola.Platform.Onboarding`) computes milestones with set-based queries (one read per milestone → `MapSet` of qualifying `store_id`s, membership-tested per store — no N+1, no schema change). A platform LiveView (`/platform/onboarding`, gated `:manage_merchants`) renders the funnel + a per-store table.

**Tech Stack:** Elixir 1.18, Ash 3.x, Phoenix LiveView, ExUnit, TailwindCSS.

**Spec:** `docs/superpowers/specs/2026-06-23-merchant-onboarding-health-design.md`

**Conventions:** TDD (test first); platform read uses `authorize?: false`; `require Ash.Query` where `filter`/`select` macros are used; commit messages end with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`; stage only this feature's files with explicit `git add <paths>` (a concurrent session's WIP is parked in `git stash` — never `git add -A`). Before pushing, run `mix test --warnings-as-errors` on the new test files (CI parity).

---

## File Structure

**Create:**
- `lib/emakola/platform/onboarding.ex` — the service: `overview/0` (per-store milestones + funnel + totals), `milestones/0` (ordered milestone keys).
- `lib/emakola_web/live/platform/onboarding_live.ex` — the platform page (funnel + table + incomplete filter).
- `test/emakola/platform/onboarding_test.exs`, `test/emakola_web/live/platform/onboarding_live_test.exs`.

**Modify:**
- `lib/emakola_web/router.ex` — route in `live_session :platform`.
- `lib/emakola_web/components/layouts/platform.html.heex` — nav link.

---

## Task 1: `Emakola.Platform.Onboarding` service

**Files:**
- Create: `lib/emakola/platform/onboarding.ex`
- Test: `test/emakola/platform/onboarding_test.exs`

- [ ] **Step 1: Write the failing test**

Create `test/emakola/platform/onboarding_test.exs`:

```elixir
defmodule Emakola.Platform.OnboardingTest do
  @moduledoc """
  Onboarding-health overview: per-store milestone booleans + completed count,
  the funnel totals, and least-complete-first ordering.
  """
  use Emakola.DataCase, async: false

  alias Emakola.Factory
  alias Emakola.Platform.Onboarding
  alias Emakola.Stores

  defp onboard_fully!(store) do
    Factory.create_product!(store)
    Factory.create_order!(store)

    {:ok, _} =
      Stores.create_payout_account(
        %{store_id: store.id, payout_destination: %{"method" => "mobile_money"}},
        authorize?: false
      )

    {:ok, v} =
      Stores.submit_store_verification(
        %{
          store_id: store.id,
          business_name: "Ama Trades",
          id_type: :ghana_card,
          id_number: "GHA-1",
          id_document_key: "k"
        },
        authorize?: false
      )

    {:ok, _} = Stores.approve_store_verification(v, authorize?: false)
    store
  end

  test "a fully-onboarded store has all milestones true and completed == 5" do
    full = Factory.create_store!() |> onboard_fully!()

    overview = Onboarding.overview()
    row = Enum.find(overview.stores, &(&1.id == full.id))

    assert row.milestones == %{
             products: true,
             live: true,
             payout: true,
             kyc: true,
             first_order: true
           }

    assert row.completed == 5
  end

  test "an archived store with nothing set up has completed == 0 (not live)" do
    {:ok, bare} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    overview = Onboarding.overview()
    row = Enum.find(overview.stores, &(&1.id == bare.id))

    assert row.milestones.live == false
    assert row.completed == 0
  end

  test "funnel counts and total reflect the stores" do
    Factory.create_store!() |> onboard_fully!()
    {:ok, _bare} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    overview = Onboarding.overview()

    assert overview.total_stores == 2
    assert overview.funnel.products == 1
    assert overview.funnel.first_order == 1
    # one live (the full one; the bare one is archived)
    assert overview.funnel.live == 1
  end

  test "stores are sorted least-complete first" do
    full = Factory.create_store!() |> onboard_fully!()
    {:ok, bare} = Stores.archive_store(Factory.create_store!(), %{}, authorize?: false)

    overview = Onboarding.overview()
    ids = Enum.map(overview.stores, & &1.id)

    assert Enum.find_index(ids, &(&1 == bare.id)) <
             Enum.find_index(ids, &(&1 == full.id))
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `mix test test/emakola/platform/onboarding_test.exs`
Expected: FAIL — `Emakola.Platform.Onboarding.overview/0` undefined.

- [ ] **Step 3: Implement the service**

Create `lib/emakola/platform/onboarding.ex`:

```elixir
defmodule Emakola.Platform.Onboarding do
  @moduledoc """
  Platform onboarding-health overview: per-store milestone completion plus an
  aggregate funnel, computed with set-based queries (one read per milestone →
  a MapSet of qualifying store_ids, membership-tested per store — no N+1, no
  schema change).

  Milestones: products added, storefront live, payout registered, KYC verified,
  first order. Read-only; called by the platform admin with authorize?: false.
  """
  require Ash.Query

  alias Emakola.Catalog.Product
  alias Emakola.Orders.Order
  alias Emakola.Stores.Store
  alias Emakola.Stores.StorePayoutAccount
  alias Emakola.Stores.StoreVerification

  @milestones [:products, :live, :payout, :kyc, :first_order]

  @doc "Ordered milestone keys (display order)."
  def milestones, do: @milestones

  @doc """
  Returns `%{total_stores, funnel, stores}` where `funnel` maps each milestone
  to the count of stores that completed it, and `stores` is a list of
  `%{id, name, slug, milestones: %{...booleans}, completed}` sorted
  least-complete first.
  """
  def overview do
    stores = Ash.read!(Store, authorize?: false)

    with_products = store_id_set(Product)
    with_payout = store_id_set(StorePayoutAccount)
    with_orders = store_id_set(Order)
    with_kyc = store_id_set(Ash.Query.filter(StoreVerification, status == :approved))

    rows =
      Enum.map(stores, fn store ->
        milestones = %{
          products: MapSet.member?(with_products, store.id),
          live: store.active == true and store.status == :active,
          payout: MapSet.member?(with_payout, store.id),
          kyc: MapSet.member?(with_kyc, store.id),
          first_order: MapSet.member?(with_orders, store.id)
        }

        %{
          id: store.id,
          name: store.name,
          slug: store.slug,
          milestones: milestones,
          completed: milestones |> Map.values() |> Enum.count(& &1)
        }
      end)

    %{
      total_stores: length(stores),
      funnel: funnel(rows),
      stores: Enum.sort_by(rows, & &1.completed)
    }
  end

  defp funnel(rows) do
    Map.new(@milestones, fn key -> {key, Enum.count(rows, & &1.milestones[key])} end)
  end

  # `queryable` is a resource module or an Ash.Query; select only store_id and
  # collapse to a MapSet for O(1) membership tests.
  defp store_id_set(queryable) do
    queryable
    |> Ash.Query.select([:store_id])
    |> Ash.read!(authorize?: false)
    |> MapSet.new(& &1.store_id)
  end
end
```

- [ ] **Step 4: Run it to confirm it passes**

Run: `mix test test/emakola/platform/onboarding_test.exs`
Expected: PASS (4 tests).

- [ ] **Step 5: Format + commit**

```bash
mix format lib/emakola/platform/onboarding.ex test/emakola/platform/onboarding_test.exs
git add lib/emakola/platform/onboarding.ex test/emakola/platform/onboarding_test.exs
git commit -m "feat(platform): merchant onboarding-health service

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `OnboardingLive` page + route + nav

**Files:**
- Create: `lib/emakola_web/live/platform/onboarding_live.ex`
- Modify: `lib/emakola_web/router.ex`
- Modify: `lib/emakola_web/components/layouts/platform.html.heex`
- Test: `test/emakola_web/live/platform/onboarding_live_test.exs`

- [ ] **Step 1: Write the failing LiveView test**

Create `test/emakola_web/live/platform/onboarding_live_test.exs`:

```elixir
defmodule EmakolaWeb.Platform.OnboardingLiveTest do
  @moduledoc """
  Platform onboarding-health page: funnel + per-store table, permission gating,
  and the incomplete-only filter.
  """
  use EmakolaWeb.ConnCase, async: false
  use Emakola.LiveViewHelpers
  import Phoenix.LiveViewTest

  alias Emakola.Factory
  alias Emakola.Stores

  test "staff without :manage_merchants is redirected", %{conn: conn} do
    {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_stores])
    assert {:error, {:redirect, _}} = live(conn, ~p"/platform/onboarding")
  end

  describe "as an owner" do
    setup %{conn: conn} do
      {conn, user, _session} = setup_platform_staff(conn)
      %{conn: conn, user: user}
    end

    test "renders the funnel and a store row", %{conn: conn} do
      store = Factory.create_store!(%{name: "Kente Kingdom"})
      Factory.create_product!(store)

      {:ok, _view, html} = live(conn, ~p"/platform/onboarding")

      assert html =~ "Onboarding"
      assert html =~ "Kente Kingdom"
      # funnel milestone label
      assert html =~ "Products"
    end

    test "the incomplete-only filter hides fully-onboarded stores", %{conn: conn} do
      full = Factory.create_store!(%{name: "Complete Co"})
      Factory.create_product!(full)
      Factory.create_order!(full)

      {:ok, _} =
        Stores.create_payout_account(
          %{store_id: full.id, payout_destination: %{"method" => "mobile_money"}},
          authorize?: false
        )

      {:ok, v} =
        Stores.submit_store_verification(
          %{
            store_id: full.id,
            business_name: "A",
            id_type: :ghana_card,
            id_number: "X",
            id_document_key: "k"
          },
          authorize?: false
        )

      {:ok, _} = Stores.approve_store_verification(v, authorize?: false)

      {:ok, view, html} = live(conn, ~p"/platform/onboarding")
      assert html =~ "Complete Co"

      html = view |> element("button[phx-click='toggle_incomplete']") |> render_click()
      refute html =~ "Complete Co"
    end
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `mix test test/emakola_web/live/platform/onboarding_live_test.exs`
Expected: FAIL — route `/platform/onboarding` not found.

- [ ] **Step 3: Implement the LiveView**

Create `lib/emakola_web/live/platform/onboarding_live.ex`:

```elixir
defmodule EmakolaWeb.Platform.OnboardingLive do
  @moduledoc """
  Platform onboarding-health page: an aggregate milestone funnel plus a
  per-store checklist table (least-complete first, with an incomplete-only
  filter). Gated by RequirePermission (:manage_merchants). No DB on
  disconnected mount.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_merchants}

  alias Emakola.Platform.Onboarding

  @labels %{
    products: "Products",
    live: "Storefront live",
    payout: "Payout",
    kyc: "KYC",
    first_order: "First order"
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Onboarding")
      |> assign(:active_nav, :onboarding)
      |> assign(:incomplete_only, false)
      |> assign(:overview, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  @impl true
  def handle_event("toggle_incomplete", _params, socket) do
    {:noreply, assign(socket, :incomplete_only, !socket.assigns.incomplete_only)}
  end

  defp load(socket), do: assign(socket, :overview, Onboarding.overview())

  defp visible_stores(stores, true), do: Enum.filter(stores, &(&1.completed < 5))
  defp visible_stores(stores, false), do: stores

  defp pct(_count, 0), do: 0
  defp pct(count, total), do: round(count / total * 100)

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :labels, @labels)

    ~H"""
    <div class="p-6 lg:p-8 max-w-5xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Onboarding</h1>
        <p class="text-sm text-gray-500 mt-1">
          How far each merchant is through setup, and where activation drops off.
        </p>
      </div>

      <p :if={is_nil(@overview)} class="text-sm text-gray-500">Loading…</p>

      <div :if={@overview}>
        <div class="bg-white rounded-xl border border-gray-200 p-6 mb-8">
          <h2 class="text-sm font-semibold text-gray-700 mb-4">
            Funnel ({@overview.total_stores} stores)
          </h2>
          <div class="space-y-3">
            <div :for={key <- Onboarding.milestones()} class="flex items-center gap-3">
              <div class="w-32 shrink-0 text-sm text-gray-600">{@labels[key]}</div>
              <div class="flex-1 bg-gray-100 rounded-full h-4 overflow-hidden">
                <div
                  class="bg-blue-500 h-4"
                  style={"width: #{pct(@overview.funnel[key], @overview.total_stores)}%"}
                >
                </div>
              </div>
              <div class="w-24 shrink-0 text-right text-sm text-gray-700">
                {@overview.funnel[key]} ({pct(@overview.funnel[key], @overview.total_stores)}%)
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-between mb-3">
          <h2 class="text-sm font-semibold text-gray-700">Merchants</h2>
          <button
            type="button"
            phx-click="toggle_incomplete"
            class={[
              "px-3 py-1.5 rounded-lg text-sm font-medium border",
              if(@incomplete_only,
                do: "bg-gray-900 text-white border-gray-900",
                else: "bg-white text-gray-600 border-gray-200 hover:bg-gray-50"
              )
            ]}
          >
            Incomplete only
          </button>
        </div>

        <div class="bg-white rounded-xl border border-gray-200 overflow-x-auto">
          <table class="w-full text-sm">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-4 py-3">Store</th>
                <th :for={key <- Onboarding.milestones()} class="px-4 py-3 text-center">
                  {@labels[key]}
                </th>
                <th class="px-4 py-3 text-right">Done</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              <tr
                :for={s <- visible_stores(@overview.stores, @incomplete_only)}
                class="hover:bg-gray-50"
              >
                <td class="px-4 py-3 font-medium text-gray-900">
                  <.link navigate={~p"/platform/stores/#{s.id}"} class="hover:text-blue-600">
                    {s.name}
                  </.link>
                </td>
                <td :for={key <- Onboarding.milestones()} class="px-4 py-3 text-center">
                  <span class={if s.milestones[key], do: "text-green-600", else: "text-gray-300"}>
                    {if s.milestones[key], do: "✓", else: "✗"}
                  </span>
                </td>
                <td class="px-4 py-3 text-right font-medium text-gray-700">{s.completed}/5</td>
              </tr>
              <tr :if={visible_stores(@overview.stores, @incomplete_only) == []}>
                <td colspan="7" class="px-4 py-12 text-center text-gray-400">No stores</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end
end
```

- [ ] **Step 4: Add the route**

In `lib/emakola_web/router.ex`, inside `live_session :platform`, after the announcements line (`live "/platform/announcements", Platform.AnnouncementLive.Index`):

```elixir
      live "/platform/onboarding", Platform.OnboardingLive
```

- [ ] **Step 5: Add the nav link**

In `lib/emakola_web/components/layouts/platform.html.heex`, mirror an existing permission-gated `<.sidebar_link>` (e.g. the announcements one) and add:

```heex
      <.sidebar_link
        :if={Emakola.Accounts.PlatformPermissions.allowed?(@current_user, :manage_merchants)}
        href="/platform/onboarding"
        title="Onboarding"
        icon="chart"
        active={@active_nav == :onboarding}
      />
```

(`chart` already exists in the shared `SidebarComponents` icon map.)

- [ ] **Step 6: Run the test to confirm it passes**

Run: `mix test test/emakola_web/live/platform/onboarding_live_test.exs`
Expected: PASS (3 tests).

- [ ] **Step 7: Format + commit**

```bash
mix format lib/emakola_web/live/platform/onboarding_live.ex lib/emakola_web/router.ex lib/emakola_web/components/layouts/platform.html.heex test/emakola_web/live/platform/onboarding_live_test.exs
git add lib/emakola_web/live/platform/onboarding_live.ex \
        lib/emakola_web/router.ex \
        lib/emakola_web/components/layouts/platform.html.heex \
        test/emakola_web/live/platform/onboarding_live_test.exs
git commit -m "feat(web): platform onboarding-health page + route + nav

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Full verification + PR

- [ ] **Step 1: Full suite**

Run: `mix test`
Expected: all pass (no regressions).

- [ ] **Step 2: Format check**

Run: `mix format --check-formatted`
Expected: clean.

- [ ] **Step 3: Credo (changed files)**

Run: `mix credo --strict lib/emakola/platform/onboarding.ex lib/emakola_web/live/platform/onboarding_live.ex`
Expected: no issues.

- [ ] **Step 4: Warnings-as-errors on new test files (CI parity)**

Run: `mix test --warnings-as-errors test/emakola/platform/onboarding_test.exs test/emakola_web/live/platform/onboarding_live_test.exs`
Expected: PASS, and no warning's `└─` line points at the new files (CI runs `mix test --warnings-as-errors`; an unused default/clause there fails CI even with 0 test failures).

- [ ] **Step 5: Push + PR**

```bash
git push -u origin feature/merchant-onboarding-health
gh pr create --base main --head feature/merchant-onboarding-health \
  --title "feat(platform): merchant onboarding health" \
  --body "Implements docs/superpowers/specs/2026-06-23-merchant-onboarding-health-design.md (plan: docs/superpowers/plans/2026-06-23-merchant-onboarding-health.md).

🤖 Generated with [Claude Code](https://claude.com/claude-code)"
```

- [ ] **Step 6: Watch CI**

Run: `gh pr checks <PR#> --watch`
Expected: Test → pass. Hand to the user to merge.

---

## Verification (acceptance)

- Service: milestone truth table (full = 5, archived-bare = 0, `live` reflects active+status), funnel counts == completions, least-complete-first sort — **Task 1 tests**.
- Page: funnel + rows render, permission gating, incomplete-only filter — **Task 2 tests**.
- Suite green + format + credo + own-files-warning-clean — **Task 3**.

## Edge cases captured

- Zero stores → `pct/2` guards division by zero (`pct(_c, 0) -> 0`); table shows "No stores".
- A fresh store is **live by default** (`active: true`, `status: :active`) — so `live` is true unless suspended/blocked/archived; tests use `archive_store` to get a not-live store.
- `store_id_set/1` selects only `:store_id` (lean) and uses `authorize?: false` so cross-tenant rows are all counted (global read).
