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
        <h1 class="text-[26px] font-black tracking-tight text-slate-900">Billing</h1>
        <p class="mt-1 text-[13.5px] text-slate-500">
          Plans, subscriptions and invoices
          <span class="text-slate-400">· amounts in USD (Stripe billing)</span>
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
          <h2 class="mb-3 text-[10.5px] font-extrabold uppercase tracking-[0.12em] text-slate-400">
            Plans
          </h2>
          <div
            :if={@plans_empty?}
            id="billing-plans-empty"
            class="rounded-2xl border border-gray-200 bg-white px-6 py-12 text-center text-sm text-gray-400"
          >
            No plans configured.
          </div>
          <div :if={!@plans_empty?} id="billing-plans-table">
            <div
              id="billing-plans"
              phx-update="stream"
              class="grid grid-cols-1 gap-3.5 sm:grid-cols-2 lg:grid-cols-3"
            >
              <div
                :for={{id, plan} <- @streams.plans}
                id={id}
                class={[
                  "rounded-2xl border bg-white p-5",
                  if(plan.active,
                    do: "border-emerald-200 shadow-lg shadow-emerald-600/5",
                    else: "border-gray-200 opacity-70"
                  )
                ]}
              >
                <div class="flex items-center justify-between">
                  <p class="text-[15px] font-extrabold text-slate-900">{plan.name}</p>
                  <span class={[
                    "rounded-full px-2.5 py-0.5 text-[10px] font-extrabold uppercase tracking-wide",
                    if(plan.active,
                      do: "bg-emerald-50 text-emerald-700",
                      else: "bg-slate-100 text-slate-500"
                    )
                  ]}>
                    {if plan.active, do: "Active", else: "Inactive"}
                  </span>
                </div>
                <p class="mt-0.5 font-mono text-[11px] text-slate-400">{plan.slug}</p>
                <p class="mt-3 text-2xl font-black text-slate-900">
                  {format_usd(plan.price_cents)}<span class="text-[13px] font-semibold text-slate-400">{interval_suffix(plan.interval)}</span>
                </p>
                <div class="mt-3 flex flex-wrap gap-1.5">
                  <span class="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-600">
                    {plan.max_seats} seats
                  </span>
                  <span class="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-600">
                    {plan.max_agents} agents
                  </span>
                  <span class="rounded-full bg-slate-100 px-2.5 py-1 text-[11px] font-semibold text-slate-600">
                    {plan.max_api_calls_per_month} API/mo
                  </span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- Subscriptions --%>
        <section>
          <h2 class="mb-3 text-[10.5px] font-extrabold uppercase tracking-[0.12em] text-slate-400">
            Subscriptions
          </h2>
          <div
            :if={@subscriptions_empty?}
            id="billing-subscriptions-empty"
            class="rounded-2xl border border-gray-200 bg-white px-6 py-12 text-center text-sm text-gray-400"
          >
            No subscriptions yet.
          </div>
          <div
            :if={!@subscriptions_empty?}
            id="billing-subscriptions-table"
            class="overflow-hidden rounded-2xl border border-gray-200 bg-white"
          >
            <div
              id="billing-subscriptions"
              phx-update="stream"
              class="divide-y divide-slate-50"
            >
              <div
                :for={{id, sub} <- @streams.subscriptions}
                id={id}
                class="flex items-center gap-3.5 px-5 py-3.5"
              >
                <div class="flex size-10 shrink-0 items-center justify-center rounded-[11px] bg-primary-soft text-sm font-extrabold text-emerald-700">
                  {org_initial(sub.organisation)}
                </div>
                <div class="min-w-0 flex-1">
                  <p class="truncate text-sm font-bold text-slate-900">
                    {(sub.organisation && sub.organisation.name) || "—"}
                  </p>
                  <p class="text-[11.5px] text-slate-400">
                    {(sub.plan && sub.plan.name) || "—"} · renews {date_str(sub.current_period_end)}
                  </p>
                </div>
                <span class={[
                  "inline-flex items-center rounded-full px-3 py-1 text-[11px] font-extrabold",
                  status_class(sub.status)
                ]}>
                  {humanize(sub.status)}
                </span>
              </div>
            </div>
          </div>
        </section>

        <%!-- Invoices --%>
        <section>
          <h2 class="mb-3 text-[10.5px] font-extrabold uppercase tracking-[0.12em] text-slate-400">
            Recent invoices
          </h2>
          <div
            :if={@invoices_empty?}
            id="billing-invoices-empty"
            class="rounded-2xl border border-gray-200 bg-white px-6 py-12 text-center text-sm text-gray-400"
          >
            No invoices yet.
          </div>
          <div
            :if={!@invoices_empty?}
            id="billing-invoices-table"
            class="overflow-hidden rounded-2xl border border-gray-200 bg-white"
          >
            <div
              id="billing-invoices"
              phx-update="stream"
              class="divide-y divide-slate-50"
            >
              <div
                :for={{id, inv} <- @streams.invoices}
                id={id}
                class="flex items-center gap-3.5 px-5 py-3.5"
              >
                <div class="min-w-0 flex-1">
                  <p class="truncate font-mono text-[12.5px] font-bold text-slate-800">
                    {inv.invoice_number}
                  </p>
                  <p class="truncate text-[11.5px] text-slate-400">
                    {(inv.organisation && inv.organisation.name) || "—"} · {date_str(inv.period_start)} – {date_str(
                      inv.period_end
                    )}
                  </p>
                </div>
                <p class="shrink-0 text-sm font-extrabold text-slate-900 tabular-nums">
                  {format_usd(inv.amount_cents)}
                </p>
                <span class={[
                  "inline-flex items-center rounded-full px-3 py-1 text-[11px] font-extrabold",
                  status_class(inv.status)
                ]}>
                  {humanize(inv.status)}
                </span>
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
    """
  end

  defp org_initial(%{name: name}) when is_binary(name) and name != "" do
    name |> String.first() |> String.upcase()
  end

  defp org_initial(_organisation), do: "?"
end
