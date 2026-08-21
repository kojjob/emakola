defmodule EmakolaWeb.Platform.BillingLive do
  @moduledoc """
  Read-only platform billing overview (plans, subscriptions, invoices).

  Gated by RequirePermission(:manage_billing). No DB queries on disconnected
  mount — a nil state renders a loading shell. Read-only: no events.

  NOTE: surfaces the existing (legacy Stripe/organisation/USD) Billing domain
  as-is. Amounts are USD cents.
  """
  use EmakolaWeb, :live_view
  require Logger

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  alias Emakola.Billing

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Billing")
      |> assign(:active_nav, :billing)
      |> stream(:plans, [])
      |> stream(:subscriptions, [])
      |> stream(:invoices, [])

    socket =
      if connected?(socket) do
        load_billing(socket)
      else
        assign(socket,
          loaded: false,
          plans_empty?: true,
          subscriptions_empty?: true,
          invoices_empty?: true,
          stats: nil
        )
      end

    {:ok, socket}
  end

  defp load_billing(socket) do
    plans = safe_list(fn -> Billing.list_plans(authorize?: false) end)

    subscriptions =
      safe_list(fn ->
        Billing.list_subscriptions(load: [:organisation, :plan], authorize?: false)
      end)

    invoices =
      safe_list(fn -> Billing.list_invoices(load: [:organisation], authorize?: false) end)

    sorted_plans = Enum.sort_by(plans, & &1.sort_order)
    recent_invoices = Enum.sort_by(invoices, & &1.period_start, {:desc, Date}) |> Enum.take(10)

    socket
    |> assign(:loaded, true)
    |> assign(:plans_empty?, sorted_plans == [])
    |> assign(:subscriptions_empty?, subscriptions == [])
    |> assign(:invoices_empty?, recent_invoices == [])
    |> assign(:stats, compute_stats(plans, subscriptions))
    |> stream(:plans, sorted_plans, reset: true)
    |> stream(:subscriptions, subscriptions, reset: true)
    |> stream(:invoices, recent_invoices, reset: true)
  end

  defp safe_list(fun) do
    case fun.() do
      {:ok, list} -> list
      _ -> []
    end
  rescue
    exception ->
      Logger.error(
        "[platform.billing_live] safe_list loading billing data raised: #{Exception.message(exception)}"
      )

      []
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
    major = div(cents, 100)
    minor = rem(abs(cents), 100) |> Integer.to_string() |> String.pad_leading(2, "0")
    "$#{major}.#{minor}"
  end

  defp format_usd(_), do: "$0.00"

  defp interval_suffix(:yearly), do: "/yr"
  defp interval_suffix(_), do: "/mo"

  defp humanize(status),
    do: status |> to_string() |> String.replace("_", " ") |> String.capitalize()

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
        class="bg-white rounded-2xl border border-gray-200 shadow-sm px-6 py-16 text-center text-sm text-gray-400"
      >
        Loading billing…
      </div>

      <div :if={@loaded} class="space-y-8">
        <%!-- Stat strip --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
          <.stat_tile
            label="MRR"
            value={format_usd(@stats.mrr_cents)}
            icon="payments"
            color="emerald"
          />
          <.stat_tile
            label="Active subscriptions"
            value={@stats.active_subscriptions}
            icon="autorenew"
            color="blue"
          />
          <.stat_tile
            label="Active plans"
            value={@stats.active_plans}
            icon="workspace_premium"
            color="violet"
          />
          <.stat_tile
            label="Needs attention"
            value={@stats.needs_attention}
            icon="warning"
            color="amber"
          />
        </div>

        <%!-- Plans --%>
        <section>
          <h2 class="text-lg font-semibold text-gray-900 mb-3">Plans</h2>
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
            <div
              :if={@plans_empty?}
              id="billing-plans-empty"
              class="px-6 py-12 text-center text-sm text-gray-400"
            >
              No plans configured.
            </div>
            <table :if={!@plans_empty?} id="billing-plans-table" class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Plan</th>
                  <th class="px-6 py-3">Price</th>
                  <th class="px-6 py-3">Limits</th>
                  <th class="px-6 py-3">Status</th>
                </tr>
              </thead>
              <tbody id="billing-plans" phx-update="stream" class="divide-y divide-gray-100">
                <tr
                  :for={{id, plan} <- @streams.plans}
                  id={id}
                  class="hover:bg-gray-50"
                >
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
                      if(plan.active,
                        do: "bg-green-100 text-green-700",
                        else: "bg-slate-100 text-slate-500"
                      )
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
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
            <div
              :if={@subscriptions_empty?}
              id="billing-subscriptions-empty"
              class="px-6 py-12 text-center text-sm text-gray-400"
            >
              No subscriptions yet.
            </div>
            <table :if={!@subscriptions_empty?} id="billing-subscriptions-table" class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Organisation</th>
                  <th class="px-6 py-3">Plan</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Renews</th>
                </tr>
              </thead>
              <tbody
                id="billing-subscriptions"
                phx-update="stream"
                class="divide-y divide-gray-100"
              >
                <tr
                  :for={{id, sub} <- @streams.subscriptions}
                  id={id}
                  class="hover:bg-gray-50"
                >
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(sub.organisation && sub.organisation.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-600">
                    {(sub.plan && sub.plan.name) || "—"}
                  </td>
                  <td class="px-6 py-4">
                    <span class={[
                      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                      status_class(sub.status)
                    ]}>
                      {humanize(sub.status)}
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
          <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
            <div
              :if={@invoices_empty?}
              id="billing-invoices-empty"
              class="px-6 py-12 text-center text-sm text-gray-400"
            >
              No invoices yet.
            </div>
            <table :if={!@invoices_empty?} id="billing-invoices-table" class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Invoice</th>
                  <th class="px-6 py-3">Organisation</th>
                  <th class="px-6 py-3">Amount</th>
                  <th class="px-6 py-3">Status</th>
                  <th class="px-6 py-3">Period</th>
                </tr>
              </thead>
              <tbody id="billing-invoices" phx-update="stream" class="divide-y divide-gray-100">
                <tr
                  :for={{id, inv} <- @streams.invoices}
                  id={id}
                  class="hover:bg-gray-50"
                >
                  <td class="px-6 py-4 text-sm font-mono text-gray-700">{inv.invoice_number}</td>
                  <td class="px-6 py-4 text-sm text-gray-600">
                    {(inv.organisation && inv.organisation.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-700 tabular-nums">
                    {format_usd(inv.amount_cents)}
                  </td>
                  <td class="px-6 py-4">
                    <span class={[
                      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                      status_class(inv.status)
                    ]}>
                      {humanize(inv.status)}
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
end
