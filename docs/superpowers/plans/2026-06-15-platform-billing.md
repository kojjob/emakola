# Platform Billing — Read-only Admin View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Ship `/platform/billing` — a read-only admin view (plans, subscriptions, invoices, MRR) over the existing `Emakola.Billing` domain. No model changes.

**Architecture:** Single LiveView (`Platform.BillingLive`) in the `:platform` live_session, gated by `RequirePermission(:manage_billing)`, disconnected-mount loading shell, no events. Mirrors `Platform.MerchantLive.Index` / `StoreLive.Index`.

**Tech Stack:** Elixir/Phoenix LiveView, Ash 3.x (Billing domain), Tailwind, ExUnit + `Emakola.LiveViewHelpers`.

**Spec:** `docs/superpowers/specs/2026-06-15-platform-billing-design.md`
**Branch:** `feature/platform-billing` (create off origin/main).

---

## Task 0: Branch

- [ ] **Step 1:** Create the branch off current origin/main:
```bash
git fetch origin
git checkout -b feature/platform-billing origin/main
```
Expected: new branch on the up-to-date base (NOT the stale local main).

---

## Task 1: Subscription factory + route + skeleton + access tests

**Files:**
- Modify: `test/support/factory.ex` (add `create_subscription!/3`)
- Modify: `lib/emakola_web/router.ex`
- Create: `lib/emakola_web/live/platform/billing_live.ex`
- Test: `test/emakola_web/live/platform/billing_live_test.exs` (create)

- [ ] **Step 1: Add the subscription factory**

In `test/support/factory.ex`, near `create_plan!`/`create_invoice!`, add:

```elixir
  def create_subscription!(org, plan, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    default = %{
      organisation_id: org.id,
      plan_id: plan.id,
      stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
      status: :active,
      current_period_start: now,
      current_period_end: DateTime.add(now, 30 * 24 * 3600, :second)
    }

    Emakola.Billing.Subscription
    |> Ash.Changeset.for_create(:create, Map.merge(default, Map.new(attrs)))
    |> Ash.create!(authorize?: false)
  end
```

(The `:create` action accepts the stripe ids/status/periods and takes `organisation_id`/`plan_id` as arguments via `manage_relationship`.)

- [ ] **Step 2: Write the failing access-control test**

Create `test/emakola_web/live/platform/billing_live_test.exs`:

```elixir
defmodule EmakolaWeb.Platform.BillingLiveTest do
  use EmakolaWeb.ConnCase, async: true

  use Emakola.LiveViewHelpers

  alias Emakola.Factory

  describe "permission gating" do
    test "owner can mount /platform/billing", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Billing"
    end

    test "staff with :manage_billing can mount", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_billing])
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Billing"
    end

    test "staff without :manage_billing is bounced to /platform", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn, permissions: [:manage_team])

      assert {:error, {:redirect, %{to: "/platform", flash: flash}}} =
               live(conn, ~p"/platform/billing")

      assert flash["error"] =~ "permission"
    end
  end
end
```

- [ ] **Step 3: Run — confirm fail** (`mix test test/emakola_web/live/platform/billing_live_test.exs`) — no route.

- [ ] **Step 4: Add the route**

In `router.ex`, inside `live_session :platform` (after `/platform/settings` or alongside the others):
```elixir
      live "/platform/billing", Platform.BillingLive
```

- [ ] **Step 5: Create the skeleton**

`lib/emakola_web/live/platform/billing_live.ex`:
```elixir
defmodule EmakolaWeb.Platform.BillingLive do
  @moduledoc "Read-only platform billing overview (plans, subscriptions, invoices)."
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Billing")
     |> assign(:active_nav, :billing)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <h1 class="text-2xl font-bold text-gray-900">Billing</h1>
      <p class="text-sm text-gray-500 mt-1">Platform plans, subscriptions & invoices</p>
    </div>
    """
  end
end
```

- [ ] **Step 6: Run — confirm pass** (3 tests). Then `mix format` the touched files.

- [ ] **Step 7: Commit**
```bash
git add test/support/factory.ex lib/emakola_web/router.ex lib/emakola_web/live/platform/billing_live.ex test/emakola_web/live/platform/billing_live_test.exs
git commit -m "feat(platform): add /platform/billing route, skeleton, subscription factory"
```

---

## Task 2: Behavior tests (red)

**Files:** Modify `test/emakola_web/live/platform/billing_live_test.exs`

- [ ] **Step 1: Append behavior tests**

```elixir
  describe "disconnected mount" do
    test "renders a loading shell without hitting the DB", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      Factory.create_plan!(%{name: "Visible Plan"})

      conn = get(conn, ~p"/platform/billing")
      html = html_response(conn, 200)

      assert html =~ "Loading"
      refute html =~ "Visible Plan"
    end
  end

  describe "content" do
    setup %{conn: conn} do
      plan = Factory.create_plan!(%{name: "Growth Plan", price_cents: 2900, interval: :monthly})
      org = Factory.create_organisation!(%{name: "Acme Org"})
      Factory.create_subscription!(org, plan, status: :active)
      Factory.create_invoice!(org, invoice_number: "INV-SHOWN", amount_cents: 2900)
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, conn: conn}
    end

    test "renders plans, subscriptions, and invoices", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "Growth Plan"
      assert html =~ "Acme Org"
      assert html =~ "INV-SHOWN"
    end

    test "stat strip shows labels and a non-zero MRR", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "MRR"
      assert html =~ "Active subscriptions"
      assert html =~ "$29.00"
    end
  end

  describe "empty state" do
    test "renders empty states when there is no billing data", %{conn: conn} do
      {conn, _user, _session} = setup_platform_staff(conn)
      {:ok, _view, html} = live(conn, ~p"/platform/billing")
      assert html =~ "No plans configured"
      assert html =~ "No subscriptions yet"
    end
  end
```

- [ ] **Step 2: Run — confirm the new tests fail** (skeleton has no stat strip / tables / loading shell). Access-control tests still pass.

- [ ] **Step 3: Commit**
```bash
git add test/emakola_web/live/platform/billing_live_test.exs
git commit -m "test(platform): behavior specs for billing overview"
```

---

## Task 3: Full LiveView (green)

**Files:** Modify `lib/emakola_web/live/platform/billing_live.ex` (full rewrite)

- [ ] **Step 1: Write the complete module**

```elixir
defmodule EmakolaWeb.Platform.BillingLive do
  @moduledoc """
  Read-only platform billing overview (plans, subscriptions, invoices).

  Gated by RequirePermission(:manage_billing). No DB queries on disconnected
  mount — a nil state renders a loading shell. Read-only: no events.

  NOTE: surfaces the existing (legacy Stripe/organisation/USD) Billing domain
  as-is. Amounts are USD cents.
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  alias Emakola.Billing

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Billing")
      |> assign(:active_nav, :billing)

    socket =
      if connected?(socket) do
        load_billing(socket)
      else
        assign(socket, loaded: false, plans: [], subscriptions: [], invoices: [], stats: nil)
      end

    {:ok, socket}
  end

  defp load_billing(socket) do
    plans = safe_list(fn -> Billing.list_plans(authorize?: false) end)

    subscriptions =
      safe_list(fn -> Billing.list_subscriptions(load: [:organisation, :plan], authorize?: false) end)

    invoices =
      safe_list(fn -> Billing.list_invoices(load: [:organisation], authorize?: false) end)

    socket
    |> assign(:loaded, true)
    |> assign(:plans, Enum.sort_by(plans, & &1.sort_order))
    |> assign(:subscriptions, subscriptions)
    |> assign(:invoices, Enum.sort_by(invoices, & &1.period_start, {:desc, Date}) |> Enum.take(10))
    |> assign(:stats, compute_stats(plans, subscriptions))
  end

  defp safe_list(fun) do
    case fun.() do
      {:ok, list} -> list
      list when is_list(list) -> list
      _ -> []
    end
  rescue
    _ -> []
  end

  defp compute_stats(plans, subscriptions) do
    active = Enum.filter(subscriptions, &(&1.status == :active))

    %{
      mrr_cents: Enum.reduce(active, 0, fn s, acc -> acc + monthly_cents(s.plan) end),
      active_subscriptions: length(active),
      active_plans: Enum.count(plans, & &1.active),
      needs_attention: Enum.count(subscriptions, &(&1.status in [:past_due, :unpaid]))
    }
  end

  defp monthly_cents(nil), do: 0
  defp monthly_cents(%{interval: :yearly, price_cents: c}), do: div(c || 0, 12)
  defp monthly_cents(%{price_cents: c}), do: c || 0

  # ── Helpers ────────────────────────────────────────────

  defp format_usd(cents) when is_integer(cents) do
    "$" <> :erlang.float_to_binary(cents / 100, decimals: 2)
  end

  defp format_usd(_), do: "$0.00"

  defp interval_suffix(:yearly), do: "/yr"
  defp interval_suffix(_), do: "/mo"

  defp status_class(:active), do: "bg-green-100 text-green-700"
  defp status_class(:trialing), do: "bg-blue-100 text-blue-700"
  defp status_class(s) when s in [:past_due, :unpaid], do: "bg-amber-100 text-amber-700"
  defp status_class(_), do: "bg-slate-100 text-slate-600"

  defp date_str(nil), do: "—"
  defp date_str(%Date{} = d), do: Calendar.strftime(d, "%b %d, %Y")
  defp date_str(%DateTime{} = d), do: Calendar.strftime(d, "%b %d, %Y")

  # ── Render ─────────────────────────────────────────────

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Billing</h1>
        <p class="text-sm text-gray-500 mt-1">
          Platform plans, subscriptions &amp; invoices
          <span class="text-gray-400">· amounts in USD (Stripe billing)</span>
        </p>
      </div>

      <div
        :if={!@loaded}
        class="bg-white rounded-xl border border-gray-200 px-6 py-16 text-center text-sm text-gray-400"
      >
        Loading billing…
      </div>

      <div :if={@loaded} class="space-y-8">
        <%!-- Stat strip --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <.stat label="MRR" value={format_usd(@stats.mrr_cents)} icon="payments" color="emerald" />
          <.stat
            label="Active subscriptions"
            value={@stats.active_subscriptions}
            icon="autorenew"
            color="blue"
          />
          <.stat label="Active plans" value={@stats.active_plans} icon="workspace_premium" color="violet" />
          <.stat label="Needs attention" value={@stats.needs_attention} icon="warning" color="amber" />
        </div>

        <%!-- Plans --%>
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Plans</h2>
          <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div :if={@plans == []} class="px-6 py-12 text-center text-sm text-gray-400">
              No plans configured.
            </div>
            <table :if={@plans != []} class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Plan</th>
                  <th class="px-6 py-3">Price</th>
                  <th class="px-6 py-3">Limits</th>
                  <th class="px-6 py-3">Status</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={plan <- @plans} class="hover:bg-gray-50">
                  <td class="px-6 py-4">
                    <p class="font-medium text-gray-900">{plan.name}</p>
                    <p class="text-xs text-gray-400 font-mono">{plan.slug}</p>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-700 tabular-nums">
                    {format_usd(plan.price_cents)}{interval_suffix(plan.interval)}
                  </td>
                  <td class="px-6 py-4 text-xs text-gray-500">
                    {plan.max_seats} seats · {plan.max_agents} agents · {plan.max_api_calls_per_month} API/mo
                  </td>
                  <td class="px-6 py-4">
                    <span class={[
                      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                      if(plan.active, do: "bg-green-100 text-green-700", else: "bg-slate-100 text-slate-500")
                    ]}>
                      {if plan.active, do: "Active", else: "Inactive"}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <%!-- Subscriptions --%>
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Subscriptions</h2>
          <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div :if={@subscriptions == []} class="px-6 py-12 text-center text-sm text-gray-400">
              No subscriptions yet.
            </div>
            <table :if={@subscriptions != []} class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Organisation</th>
                  <th class="px-6 py-3">Plan</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Renews</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={sub <- @subscriptions} class="hover:bg-gray-50">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(sub.organisation && sub.organisation.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-600">
                    {(sub.plan && sub.plan.name) || "—"}
                  </td>
                  <td class="px-6 py-4">
                    <span class={["inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium", status_class(sub.status)]}>
                      {sub.status}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">{date_str(sub.current_period_end)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <%!-- Invoices --%>
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Recent invoices</h2>
          <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
            <div :if={@invoices == []} class="px-6 py-12 text-center text-sm text-gray-400">
              No invoices yet.
            </div>
            <table :if={@invoices != []} class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Invoice</th>
                  <th class="px-6 py-3">Organisation</th>
                  <th class="px-6 py-3">Amount</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Period</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={inv <- @invoices} class="hover:bg-gray-50">
                  <td class="px-6 py-4 text-sm font-mono text-gray-700">{inv.invoice_number}</td>
                  <td class="px-6 py-4 text-sm text-gray-600">
                    {(inv.organisation && inv.organisation.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-700 tabular-nums">{format_usd(inv.amount_cents)}</td>
                  <td class="px-6 py-4">
                    <span class={["inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium", status_class(inv.status)]}>
                      {inv.status}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">
                    {date_str(inv.period_start)} – {date_str(inv.period_end)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>
    """
  end

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

    assigns =
      assign(assigns, :color_class, Map.get(color_classes, assigns.color, "bg-gray-50 text-gray-600"))

    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-5">
      <span class={"material-symbols-outlined text-xl rounded-lg p-2 #{@color_class}"}>{@icon}</span>
      <p class="text-2xl font-bold text-gray-900 tabular-nums mt-3">{@value}</p>
      <p class="text-sm text-gray-500 mt-1">{@label}</p>
    </div>
    """
  end
end
```

- [ ] **Step 2: Run the billing tests** (`mix test test/emakola_web/live/platform/billing_live_test.exs`) — all pass. If `$29.00` assertion fails, check `format_usd/1` output formatting.

- [ ] **Step 3:** `mix format` + `mix compile --warnings-as-errors` (fix warnings in the new file).

- [ ] **Step 4: Swap the Billing nav stub**

In `lib/emakola_web/components/layouts/platform.html.heex`, replace the disabled Billing `<a href="#" ... title="Billing" ...>…Soon…</a>` block (under the `Finance` section label) with:
```heex
      <.sidebar_link
        :if={Emakola.Accounts.PlatformPermissions.allowed?(@current_user, :manage_billing)}
        href="/platform/billing"
        title="Billing"
        icon="currency"
        active={@active_nav == :billing}
      />
```
Leave the `Finance` section label intact.

- [ ] **Step 5: Commit**
```bash
git add lib/emakola_web/live/platform/billing_live.ex lib/emakola_web/components/layouts/platform.html.heex
git commit -m "feat(platform): read-only billing overview (plans, subscriptions, invoices, MRR)"
```

---

## Task 4: Quality gates

- [ ] **Step 1:** `mix format --check-formatted` → clean.
- [ ] **Step 2:** `mix credo --strict lib/emakola_web/live/platform/billing_live.ex` → no issues.
- [ ] **Step 3:** `mix test` → full suite green (no regressions from the `create_subscription!` factory addition).

---

## Self-review notes (author)
- **Spec coverage:** route + nav + gating (Task 1), behavior tests (Task 2), stat strip / plans / subscriptions / invoices / loading shell / empty states (Task 3). ✅
- **Conventions applied:** branch off **origin/main** (Task 0 — avoids the stale-base trap), `RequirePermission(:manage_billing)`, disconnected-mount loading shell, `setup_platform_staff` tests, permission-gated nav. Read-only ⇒ no per-event re-auth needed.
- **Money:** USD via `format_usd` (cents/100) — matches the legacy Stripe domain; the page header states this explicitly.
- **Defensive:** `safe_list/1` tolerates `{:ok, list}` or bare list from the code interfaces and rescues to `[]`; nil-safe org/plan access in the template.
- **No placeholders.**
