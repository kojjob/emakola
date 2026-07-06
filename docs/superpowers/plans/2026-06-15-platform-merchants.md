# Platform Merchants — Directory + Drill-down Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/platform/merchants` — a searchable, filterable directory of all merchants with a slide-over detail drawer showing each merchant's profile and their stores+roles. Read-only, no new DB models.

**Architecture:** A single LiveView (`Platform.MerchantLive.Index`) in the existing `:platform` live_session. Streams table + always-rendered `<.modal kind={:slide_over}>` drawer. New `Merchant.list_for_admin` read action mirrors `Store.list_for_admin`; the drawer loads roles via `store_memberships: [:store]`.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x (Accounts domain), Tailwind, core_components `<.modal>` / `show_modal`, ExUnit + LiveViewTest.

**Spec:** `docs/superpowers/specs/2026-06-15-platform-merchants-design.md`
**Branch:** `feature/platform-merchants` (created; spec committed).

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/emakola/accounts/resources/merchant.ex` | `read :list_for_admin` | Modify |
| `lib/emakola/accounts/accounts.ex` | `list_merchants_for_admin` + `get_merchant` defines | Modify |
| `test/support/factory.ex` | enhance `create_merchant!` (name/business/phone/confirmed_at) | Modify |
| `lib/emakola_web/router.ex` | route `/platform/merchants` | Modify |
| `lib/emakola_web/live/platform/merchant_live/index.ex` | the page | Create |
| `test/emakola/accounts/merchant_admin_test.exs` | domain action test | Create |
| `test/emakola_web/live/platform/merchant_live/index_test.exs` | LiveView tests | Create |

No layout change — the `Merchants` sidebar link already exists and activates on `@active_nav == :merchants`.

---

## Task 1: Domain action, interfaces, and factory enhancement

**Files:**
- Modify: `lib/emakola/accounts/resources/merchant.ex`
- Modify: `lib/emakola/accounts/accounts.ex`
- Modify: `test/support/factory.ex`
- Test: `test/emakola/accounts/merchant_admin_test.exs` (create)

- [ ] **Step 1: Write the failing test**

Create `test/emakola/accounts/merchant_admin_test.exs`:

```elixir
defmodule Emakola.Accounts.MerchantAdminTest do
  use Emakola.DataCase, async: true

  alias Emakola.Accounts
  alias Emakola.Factory

  describe "list_merchants_for_admin/1" do
    test "returns all merchants when search is blank" do
      Factory.create_merchant!(%{name: "Ama Mensah", email: "ama@example.com"})
      Factory.create_merchant!(%{name: "Kofi Boateng", email: "kofi@example.com"})

      assert {:ok, merchants} = Accounts.list_merchants_for_admin("", authorize?: false)
      assert length(merchants) == 2
    end

    test "filters by name (case-insensitive)" do
      Factory.create_merchant!(%{name: "Ama Mensah", email: "ama@example.com"})
      Factory.create_merchant!(%{name: "Kofi Boateng", email: "kofi@example.com"})

      assert {:ok, [m]} = Accounts.list_merchants_for_admin("%ama%", authorize?: false)
      assert m.name == "Ama Mensah"
    end

    test "filters by email" do
      Factory.create_merchant!(%{name: "Ama", email: "ama@example.com"})
      Factory.create_merchant!(%{name: "Kofi", email: "kofi@example.com"})

      assert {:ok, [m]} = Accounts.list_merchants_for_admin("%kofi@%", authorize?: false)
      assert to_string(m.email) == "kofi@example.com"
    end

    test "loads stores association" do
      {merchant, _store} = Factory.create_merchant_with_store!()
      {:ok, merchants} = Accounts.list_merchants_for_admin("", authorize?: false)
      found = Enum.find(merchants, &(&1.id == merchant.id))
      assert length(found.stores) == 1
    end
  end

  describe "create_merchant! factory enhancement" do
    test "applies name/business/phone and confirmed_at when given" do
      ts = DateTime.utc_now()
      m = Factory.create_merchant!(%{name: "Ama", business_name: "Ama Foods", phone: "0244", confirmed_at: ts})
      assert m.name == "Ama"
      assert m.business_name == "Ama Foods"
      assert m.phone == "0244"
      refute is_nil(m.confirmed_at)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mix test test/emakola/accounts/merchant_admin_test.exs`
Expected: FAIL — `Accounts.list_merchants_for_admin/2` undefined; factory ignores name.

- [ ] **Step 3: Add the `list_for_admin` read action**

In `lib/emakola/accounts/resources/merchant.ex`, inside the `actions do ... end` block (after `defaults([:read])`), add:

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

- [ ] **Step 4: Add the domain interfaces**

In `lib/emakola/accounts/accounts.ex`, inside `resource Emakola.Accounts.Merchant do`, add:

```elixir
      define(:list_merchants_for_admin, action: :list_for_admin, args: [:search])
      define(:get_merchant, action: :read, get_by: [:id])
```

(Keep the existing `define(:update_merchant_profile, action: :update_profile)`.)

- [ ] **Step 5: Enhance the factory (backward-compatible)**

In `test/support/factory.ex`, replace the existing `create_merchant!/1` with:

```elixir
  def create_merchant!(attrs \\ %{}) do
    attrs = Map.new(attrs)

    merchant =
      Emakola.Accounts.Merchant
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: attrs[:email] || unique_email(),
        password: attrs[:password] || "Password123!",
        password_confirmation: attrs[:password_confirmation] || attrs[:password] || "Password123!"
      })
      |> Ash.create!(authorize?: false)

    profile = Map.take(attrs, [:name, :business_name, :phone, :avatar_url])

    merchant =
      if profile == %{} do
        merchant
      else
        merchant
        |> Ash.Changeset.for_update(:update_profile, profile)
        |> Ash.update!(authorize?: false)
      end

    case attrs[:confirmed_at] do
      nil ->
        merchant

      ts ->
        merchant
        |> Ash.Changeset.for_update(:update_profile, %{})
        |> Ash.Changeset.force_change_attribute(:confirmed_at, ts)
        |> Ash.update!(authorize?: false)
    end
  end
```

This is additive: existing callers (no attrs, or only email/password) get identical behavior.

- [ ] **Step 6: Run test to verify it passes**

Run: `mix test test/emakola/accounts/merchant_admin_test.exs`
Expected: PASS (5 tests).

- [ ] **Step 7: Format & commit**

```bash
mix format lib/emakola/accounts/resources/merchant.ex lib/emakola/accounts/accounts.ex test/support/factory.ex test/emakola/accounts/merchant_admin_test.exs
git add lib/emakola/accounts/resources/merchant.ex lib/emakola/accounts/accounts.ex test/support/factory.ex test/emakola/accounts/merchant_admin_test.exs
git commit -m "feat(accounts): merchant list_for_admin action + admin interfaces + factory profile attrs"
```

---

## Task 2: Route + LiveView skeleton + access tests

**Files:**
- Modify: `lib/emakola_web/router.ex`
- Create: `lib/emakola_web/live/platform/merchant_live/index.ex`
- Test: `test/emakola_web/live/platform/merchant_live/index_test.exs` (create)

- [ ] **Step 1: Write the failing test**

Create `test/emakola_web/live/platform/merchant_live/index_test.exs`:

```elixir
defmodule EmakolaWeb.Platform.MerchantLive.IndexTest do
  use EmakolaWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  alias Emakola.Factory

  defp log_in_platform_admin(conn) do
    admin = Factory.create_platform_admin!()
    token = AshAuthentication.user_to_subject(admin)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "access control" do
    test "platform admin can load the page", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Merchants"
    end

    test "a non-admin merchant is redirected", %{conn: conn} do
      {merchant, _store} = Factory.create_merchant_with_store!()
      token = AshAuthentication.user_to_subject(merchant)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/platform/merchants")
    end
  end
end
```

- [ ] **Step 2: Run to verify it fails**

Run: `mix test test/emakola_web/live/platform/merchant_live/index_test.exs`
Expected: FAIL — no route for `/platform/merchants`.

- [ ] **Step 3: Add the route**

In `lib/emakola_web/router.ex`, inside the `live_session :platform` block (after `/platform/settings`):

```elixir
      live "/platform/merchants", Platform.MerchantLive.Index
```

- [ ] **Step 4: Create the skeleton**

Create `lib/emakola_web/live/platform/merchant_live/index.ex`:

```elixir
defmodule EmakolaWeb.Platform.MerchantLive.Index do
  @moduledoc "Platform directory of all merchants with a slide-over detail drawer."
  use EmakolaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Merchants")
     |> assign(:active_nav, :merchants)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Merchants</h1>
      <p class="text-sm text-gray-500 mt-1">Everyone building on Emakola</p>
    </div>
    """
  end
end
```

- [ ] **Step 5: Run to verify it passes**

Run: `mix test test/emakola_web/live/platform/merchant_live/index_test.exs`
Expected: PASS (2 tests).

- [ ] **Step 6: Format & commit**

```bash
mix format lib/emakola_web/router.ex lib/emakola_web/live/platform/merchant_live/index.ex test/emakola_web/live/platform/merchant_live/index_test.exs
git add lib/emakola_web/router.ex lib/emakola_web/live/platform/merchant_live/index.ex test/emakola_web/live/platform/merchant_live/index_test.exs
git commit -m "feat(platform): add /platform/merchants route, nav active, and skeleton"
```

---

## Task 3: Full behavior tests (red)

**Files:**
- Modify: `test/emakola_web/live/platform/merchant_live/index_test.exs`

- [ ] **Step 1: Append behavior tests**

Add these describe blocks to the test module (keep the access-control block + helper):

```elixir
  describe "listing & stats" do
    setup %{conn: conn} do
      ts = DateTime.utc_now()
      Factory.create_merchant!(%{name: "Ama Mensah", email: "ama@example.com", business_name: "Ama Foods", confirmed_at: ts})
      {kofi, store} = Factory.create_merchant_with_store!()
      Factory.create_merchant!(%{name: "Yaw Owusu", email: "yaw@example.com"})

      # confirm kofi and give them a known name for assertions
      kofi
      |> Ash.Changeset.for_update(:update_profile, %{name: "Kofi Boateng"})
      |> Ash.update!(authorize?: false)
      |> Ash.Changeset.for_update(:update_profile, %{})
      |> Ash.Changeset.force_change_attribute(:confirmed_at, ts)
      |> Ash.update!(authorize?: false)

      {:ok, conn: log_in_platform_admin(conn), store: store, kofi: kofi}
    end

    test "renders merchants with names and emails", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      for s <- ["Ama Mensah", "ama@example.com", "Yaw Owusu"], do: assert(html =~ s)
    end

    test "stat strip shows labels and total", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "Total"
      assert html =~ "Confirmed"
      assert html =~ "With a store"
      assert html =~ "New"
    end

    test "search narrows by name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      html = view |> form("#merchant-search-form") |> render_change(%{"search" => "Ama"})
      assert html =~ "Ama Mensah"
      refute html =~ "Yaw Owusu"
    end

    test "search narrows by email", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      html = view |> form("#merchant-search-form") |> render_change(%{"search" => "yaw@"})
      assert html =~ "Yaw Owusu"
      refute html =~ "Ama Mensah"
    end

    test "unconfirmed filter shows only unconfirmed merchants", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      html = render_click(view, "filter", %{"filter" => "unconfirmed"})
      assert html =~ "Yaw Owusu"
      refute html =~ "Ama Mensah"
    end
  end

  describe "drill-down drawer" do
    test "selecting a merchant loads their stores and roles", %{conn: conn} do
      m = Factory.create_merchant!(%{name: "Esi Owl", email: "esi@example.com"})
      store = Factory.create_store!(%{name: "Owl Boutique"})
      Factory.create_store_membership!(m, store, :owner)
      conn = log_in_platform_admin(conn)

      {:ok, view, _html} = live(conn, ~p"/platform/merchants")
      html = render_click(view, "select_merchant", %{"id" => m.id})

      assert html =~ "Esi Owl"
      assert html =~ "Owl Boutique"
      assert html =~ "owner"
    end
  end

  describe "empty state" do
    test "renders when no merchants exist", %{conn: conn} do
      conn = log_in_platform_admin(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/merchants")
      assert html =~ "No merchants yet"
    end
  end
```

- [ ] **Step 2: Run to verify failure (red)**

Run: `mix test test/emakola_web/live/platform/merchant_live/index_test.exs`
Expected: access-control tests PASS; new behavior tests FAIL (skeleton has no stat strip, search form, events, drawer, empty state).

- [ ] **Step 3: Commit failing tests**

```bash
git add test/emakola_web/live/platform/merchant_live/index_test.exs
git commit -m "test(platform): behavior specs for merchants directory + drawer"
```

---

## Task 4: Full LiveView implementation (green)

**Files:**
- Modify: `lib/emakola_web/live/platform/merchant_live/index.ex` (full rewrite)

- [ ] **Step 1: Write the complete module**

Overwrite `lib/emakola_web/live/platform/merchant_live/index.ex` with:

```elixir
defmodule EmakolaWeb.Platform.MerchantLive.Index do
  @moduledoc "Platform directory of all merchants with a slide-over detail drawer."
  use EmakolaWeb, :live_view

  alias Emakola.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Merchants")
     |> assign(:active_nav, :merchants)
     |> assign(:search, "")
     |> assign(:filter, :all)
     |> assign(:selected_merchant, nil)
     |> load_merchants()}
  end

  # ── Events ─────────────────────────────────────────────

  @impl true
  def handle_event("search", %{"search" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> put_merchants()}
  end

  def handle_event("filter", %{"filter" => f}, socket) do
    {:noreply, socket |> assign(:filter, parse_filter(f)) |> put_merchants()}
  end

  def handle_event("select_merchant", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_merchant, load_merchant_detail(id))}
  end

  # ── Data ───────────────────────────────────────────────

  defp load_merchants(socket) do
    all = list_all_merchants()

    socket
    |> assign(:all_merchants, all)
    |> assign(:stats, compute_stats(all))
    |> put_merchants()
  end

  defp put_merchants(socket) do
    visible = filtered(socket.assigns.all_merchants, socket.assigns.search, socket.assigns.filter)

    socket
    |> assign(:filtered_count, length(visible))
    |> stream(:merchants, visible, reset: true)
  end

  defp list_all_merchants do
    case Accounts.list_merchants_for_admin("", authorize?: false) do
      {:ok, list} -> list
      _ -> []
    end
  rescue
    _ -> []
  end

  defp load_merchant_detail(id) do
    case Accounts.get_merchant(id, load: [store_memberships: [:store]], authorize?: false) do
      {:ok, merchant} -> merchant
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp filtered(all, search, filter) do
    q = normalize(search)
    Enum.filter(all, &(matches_search?(&1, q) and matches_filter?(&1, filter)))
  end

  defp matches_search?(_m, ""), do: true

  defp matches_search?(m, q) do
    [m.name, to_string(m.email), m.business_name, m.phone]
    |> Enum.any?(fn v -> v && String.contains?(String.downcase(to_string(v)), q) end)
  end

  defp matches_filter?(_m, :all), do: true
  defp matches_filter?(m, :confirmed), do: confirmed?(m)
  defp matches_filter?(m, :unconfirmed), do: not confirmed?(m)

  defp confirmed?(m), do: not is_nil(m.confirmed_at)

  defp compute_stats(all) do
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 24 * 3600, :second)

    %{
      total: length(all),
      confirmed: Enum.count(all, &confirmed?/1),
      with_store: Enum.count(all, fn m -> length(m.stores || []) > 0 end),
      new_30d: Enum.count(all, fn m -> DateTime.compare(m.inserted_at, cutoff) == :gt end)
    }
  end

  # ── Helpers ────────────────────────────────────────────

  defp normalize(s), do: s |> to_string() |> String.trim() |> String.downcase()

  defp parse_filter("confirmed"), do: :confirmed
  defp parse_filter("unconfirmed"), do: :unconfirmed
  defp parse_filter(_), do: :all

  defp initials(m) do
    source = m.name || to_string(m.email) || "?"

    source
    |> String.split(~r/[\s@.]+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
    |> case do
      "" -> "?"
      s -> s
    end
  end

  defp store_count(m), do: length(m.stores || [])

  defp role_class(:owner), do: "bg-blue-100 text-blue-700"
  defp role_class(:admin), do: "bg-violet-100 text-violet-700"
  defp role_class(_), do: "bg-slate-100 text-slate-600"

  # ── Render ─────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Header --%>
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Merchants</h1>
        <p class="text-sm text-gray-500 mt-1">
          Everyone building on Emakola ({@stats.total})
        </p>
      </div>

      <%!-- Stat strip --%>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <.stat label="Total" value={@stats.total} icon="group" color="blue" />
        <.stat label="Confirmed" value={@stats.confirmed} icon="verified" color="emerald" />
        <.stat label="With a store" value={@stats.with_store} icon="storefront" color="violet" />
        <.stat label="New (30d)" value={@stats.new_30d} icon="trending_up" color="amber" />
      </div>

      <%!-- Toolbar --%>
      <div class="mb-5 flex items-center gap-3 flex-wrap">
        <form id="merchant-search-form" phx-change="search" class="relative flex-1 min-w-[200px] max-w-sm">
          <span class="material-symbols-outlined text-base text-gray-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none">
            search
          </span>
          <input
            type="search"
            name="search"
            value={@search}
            placeholder="Search name, email, business, phone..."
            phx-debounce="300"
            class="w-full pl-10 pr-4 py-2.5 bg-white border border-gray-200 rounded-xl text-sm text-gray-700 placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-400 transition-all"
          />
        </form>
        <div class="flex items-center gap-1.5">
          <.chip filter="all" active={@filter} label="All" />
          <.chip filter="confirmed" active={@filter} label="Confirmed" />
          <.chip filter="unconfirmed" active={@filter} label="Unconfirmed" />
        </div>
      </div>

      <%!-- Empty states --%>
      <div
        :if={@stats.total == 0}
        class="bg-white rounded-xl border border-gray-200 px-6 py-16 text-center"
      >
        <span class="material-symbols-outlined text-4xl text-gray-300">group</span>
        <p class="mt-2 text-sm font-medium text-gray-900">No merchants yet</p>
        <p class="text-sm text-gray-400">Merchants will appear here as they sign up.</p>
      </div>

      <div
        :if={@stats.total > 0 and @filtered_count == 0}
        class="bg-white rounded-xl border border-gray-200 px-6 py-16 text-center text-sm text-gray-400"
      >
        No merchants match your filters
      </div>

      <%!-- Table --%>
      <div :if={@filtered_count > 0} class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                <th class="px-6 py-3">Merchant</th>
                <th class="px-6 py-3">Business</th>
                <th class="px-6 py-3">Stores</th>
                <th class="px-6 py-3">Status</th>
                <th class="px-6 py-3">Joined</th>
              </tr>
            </thead>
            <tbody id="merchants" phx-update="stream" class="divide-y divide-gray-100">
              <tr
                :for={{dom_id, m} <- @streams.merchants}
                id={dom_id}
                class="hover:bg-gray-50 transition-colors cursor-pointer"
                phx-click={JS.push("select_merchant", value: %{id: m.id}) |> show_modal("merchant-drawer")}
              >
                <td class="px-6 py-4">
                  <div class="flex items-center gap-3">
                    <div class="w-9 h-9 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-sm font-bold shrink-0 overflow-hidden">
                      <img :if={m.avatar_url} src={m.avatar_url} alt="" class="w-full h-full object-cover" />
                      <span :if={is_nil(m.avatar_url)}>{initials(m)}</span>
                    </div>
                    <div class="min-w-0">
                      <p class="font-medium text-gray-900 truncate">{m.name || "—"}</p>
                      <p class="text-xs text-gray-400 truncate">{m.email}</p>
                    </div>
                  </div>
                </td>
                <td class="px-6 py-4 text-sm text-gray-600">{m.business_name || "—"}</td>
                <td class="px-6 py-4">
                  <span
                    :if={store_count(m) > 0}
                    class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600"
                  >
                    {store_count(m)} {if store_count(m) == 1, do: "store", else: "stores"}
                  </span>
                  <span :if={store_count(m) == 0} class="text-xs text-gray-400">—</span>
                </td>
                <td class="px-6 py-4">
                  <span class={[
                    "inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium",
                    if(confirmed?(m), do: "bg-green-100 text-green-700", else: "bg-amber-100 text-amber-700")
                  ]}>
                    <span class={[
                      "w-1.5 h-1.5 rounded-full",
                      if(confirmed?(m), do: "bg-green-500", else: "bg-amber-500")
                    ]}>
                    </span>
                    {if confirmed?(m), do: "Confirmed", else: "Pending"}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-gray-500">
                  {Calendar.strftime(m.inserted_at, "%b %d, %Y")}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <%!-- Detail drawer (always rendered, nil-safe) --%>
      <.modal id="merchant-drawer" kind={:slide_over} title="Merchant">
        <div :if={@selected_merchant} class="space-y-6">
          <% m = @selected_merchant %>
          <%!-- Profile header --%>
          <div class="flex items-center gap-4">
            <div class="w-16 h-16 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 text-xl font-bold shrink-0 overflow-hidden">
              <img :if={m.avatar_url} src={m.avatar_url} alt="" class="w-full h-full object-cover" />
              <span :if={is_nil(m.avatar_url)}>{initials(m)}</span>
            </div>
            <div class="min-w-0">
              <h3 class="text-lg font-semibold text-gray-900 truncate">{m.name || "—"}</h3>
              <p class="text-sm text-gray-500 truncate">{m.email}</p>
              <span class={[
                "inline-flex items-center gap-1.5 px-2 py-0.5 mt-1 rounded-full text-xs font-medium",
                if(confirmed?(m), do: "bg-green-100 text-green-700", else: "bg-amber-100 text-amber-700")
              ]}>
                {if confirmed?(m), do: "Confirmed", else: "Pending"}
              </span>
            </div>
          </div>

          <%!-- Meta --%>
          <dl class="grid grid-cols-2 gap-4 text-sm">
            <div>
              <dt class="text-gray-400">Business</dt>
              <dd class="text-gray-900">{m.business_name || "—"}</dd>
            </div>
            <div>
              <dt class="text-gray-400">Phone</dt>
              <dd class="text-gray-900">{m.phone || "—"}</dd>
            </div>
            <div>
              <dt class="text-gray-400">Joined</dt>
              <dd class="text-gray-900">{Calendar.strftime(m.inserted_at, "%b %d, %Y")}</dd>
            </div>
            <div>
              <dt class="text-gray-400">Stores</dt>
              <dd class="text-gray-900">{length(m.store_memberships)}</dd>
            </div>
          </dl>

          <%!-- Stores + roles --%>
          <div>
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-2">Stores</h4>
            <div :if={m.store_memberships == []} class="text-sm text-gray-400">
              This merchant has no stores yet.
            </div>
            <ul class="space-y-2">
              <li
                :for={sm <- m.store_memberships}
                class="flex items-center justify-between gap-3 p-3 rounded-xl border border-gray-100"
              >
                <div class="min-w-0">
                  <p class="font-medium text-gray-900 truncate">{sm.store.name}</p>
                  <p class="text-xs text-gray-400 font-mono truncate">{sm.store.slug}</p>
                </div>
                <div class="flex items-center gap-2 shrink-0">
                  <span class={["px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide", role_class(sm.role)]}>
                    {sm.role}
                  </span>
                  <a
                    href={"/s/#{sm.store.slug}"}
                    target="_blank"
                    class="text-xs text-blue-600 hover:text-blue-700 font-medium inline-flex items-center gap-0.5"
                  >
                    View <span class="material-symbols-outlined" style="font-size: 13px;">open_in_new</span>
                  </a>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </.modal>
    </div>
    """
  end

  # ── Function components ─────────────────────────────────

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, required: true

  defp stat(assigns) do
    color_classes = %{
      "blue" => "bg-blue-50 text-blue-600",
      "emerald" => "bg-emerald-50 text-emerald-600",
      "violet" => "bg-violet-50 text-violet-600",
      "amber" => "bg-amber-50 text-amber-600"
    }

    assigns = assign(assigns, :color_class, Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600"))

    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-5">
      <span class={"material-symbols-outlined text-xl rounded-lg p-2 #{@color_class}"}>
        {@icon}
      </span>
      <p class="text-2xl font-bold text-gray-900 tabular-nums mt-3">{@value}</p>
      <p class="text-sm text-gray-500 mt-1">{@label}</p>
    </div>
    """
  end

  attr :filter, :string, required: true
  attr :active, :atom, required: true
  attr :label, :string, required: true

  defp chip(assigns) do
    assigns = assign(assigns, :is_active, to_string(assigns.active) == assigns.filter)

    ~H"""
    <button
      type="button"
      phx-click="filter"
      phx-value-filter={@filter}
      class={[
        "px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors",
        if(@is_active,
          do: "bg-blue-600 text-white",
          else: "bg-white border border-gray-200 text-gray-600 hover:bg-gray-50"
        )
      ]}
    >
      {@label}
    </button>
    """
  end
end
```

- [ ] **Step 2: Run the LiveView tests**

Run: `mix test test/emakola_web/live/platform/merchant_live/index_test.exs`
Expected: ALL pass (access-control + behavior). If the drawer test fails on role text, confirm the role atom renders (e.g. `owner`) — `{sm.role}` prints the atom. If a test fails because the drawer content isn't in the rendered HTML after `select_merchant`, note the drawer is always rendered (no `:if` on `<.modal>` itself), so `@selected_merchant` content appears in the diff. Do NOT weaken tests.

- [ ] **Step 3: Format + warnings check**

Run: `mix format lib/emakola_web/live/platform/merchant_live/index.ex`
Run: `mix compile --warnings-as-errors` (fix any warnings in the new file; e.g. unused alias `Merchant` if present — the module aliases only `Accounts`).

- [ ] **Step 4: Commit**

```bash
git add lib/emakola_web/live/platform/merchant_live/index.ex
git commit -m "feat(platform): full merchants directory with slide-over detail drawer"
```

---

## Task 5: Quality gates

**Files:** none (verification only)

- [ ] **Step 1:** `mix format --check-formatted` → clean.
- [ ] **Step 2:** `mix credo --strict lib/emakola_web/live/platform/merchant_live/index.ex lib/emakola/accounts/resources/merchant.ex lib/emakola/accounts/accounts.ex` → no issues.
- [ ] **Step 3:** `mix test` → full suite green, no regressions (esp. existing tests that use `create_merchant!` — verify the factory change didn't break them).
- [ ] **Step 4 (optional smoke):** `PORT=4010 mix phx.server`, log in as the seeded platform admin, visit `/platform/merchants`, click a row → drawer. Stop server after.

---

## Self-review notes (author)

- **Spec coverage:** list action + interfaces (Task 1), route + skeleton (Task 2), stat strip / search / filter / table / drawer / empty states (Task 4); domain + LiveView tests across Tasks 1–3. ✅
- **Lessons applied:** drawer is **always rendered, nil-safe** (no `:if` on `<.modal>` — avoids the Settings race); `parse_filter/1` allowlist (no `String.to_atom`); `DateTime.utc_now` called inside `compute_stats/0`, not at module load.
- **Factory change is backward-compatible** (additive profile/confirmed application only when attrs given) — Task 5 Step 3 explicitly re-runs the full suite to confirm no regression in existing `create_merchant!` callers.
- **Known accepted duplication:** `stat/1` + `chip/1` mirror `SettingsLive` (platform-wide component extraction is a tracked follow-up, deliberately out of scope here).
- **No placeholders.**
