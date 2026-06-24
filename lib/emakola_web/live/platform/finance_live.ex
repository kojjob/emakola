defmodule EmakolaWeb.Platform.FinanceLive do
  @moduledoc """
  Read-only platform finance overview (`/platform/finance`) — the money view.

  Surfaces platform revenue (transaction fees collected), GMV, the effective
  take rate, and the outstanding merchant-payout backlog, with a per-store
  breakdown that flags which stores still owe a manual payout because they have
  no verified subaccount yet. Distinct from `/platform/payments` (transaction
  ops) and `/platform/billing` (legacy Stripe subscriptions).
  """
  use EmakolaWeb, :live_view

  alias Emakola.Platform.FinanceStats
  alias Emakola.Platform.Stats

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Finance")
      |> assign(:active_nav, :finance)

    socket =
      if connected?(socket) do
        load(socket)
      else
        assign(socket, loaded: false, stats: nil, take_rate: nil, stores: [])
      end

    {:ok, socket}
  end

  defp load(socket) do
    fees = FinanceStats.total_platform_fees()
    outstanding = FinanceStats.total_outstanding_payouts()
    gmv = Stats.total_gmv()

    take_rate = if gmv > 0, do: fees / gmv, else: nil

    socket
    |> assign(:loaded, true)
    |> assign(:stats, %{fees: fees, outstanding: outstanding, gmv: gmv})
    |> assign(:take_rate, take_rate)
    |> assign(:stores, FinanceStats.per_store_finance())
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Finance</h1>
        <p class="text-sm text-gray-500 mt-1">
          Platform revenue &amp; merchant payout balances across all stores
        </p>
      </div>

      <%= if @loaded == false do %>
        <div class="text-center py-16 text-gray-400">
          <p class="text-sm">Loading finance data…</p>
        </div>
      <% else %>
        <%!-- ── Revenue stat strip ─────────────────────────────────────── --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <.stat_tile
            label="Platform fees collected"
            value={format_amount(@stats.fees)}
            icon="currency"
            color="emerald"
          />
          <.stat_tile label="GMV" value={format_amount(@stats.gmv)} icon="chart" color="blue" />
          <.stat_tile
            label="Effective take rate"
            value={format_rate(@take_rate)}
            icon="chart"
            color="violet"
          />
          <.stat_tile
            label="Outstanding payouts"
            value={format_amount(@stats.outstanding)}
            icon="payments"
            color="amber"
          />
        </div>

        <%!-- ── Per-store breakdown ────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">By store</h2>
            <p class="text-xs text-gray-400 mt-0.5">
              Sorted by outstanding balance — the manual-payout worklist
            </p>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Fees collected</th>
                  <th class="px-6 py-3">Outstanding owed</th>
                  <th class="px-6 py-3">Payouts</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :if={@stores == []}>
                  <td colspan="4" class="px-6 py-12 text-center text-sm text-gray-400">
                    No finance activity yet.
                  </td>
                </tr>
                <tr :for={row <- @stores} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {(row.store && row.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-emerald-700">
                    {format_amount(row.fees_collected)}
                  </td>
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {format_amount(row.outstanding_owed)}
                  </td>
                  <td class="px-6 py-4 text-sm">
                    <span :if={row.payouts_ready?} class={pill_class(:ready)}>Ready</span>
                    <span :if={!row.payouts_ready?} class={pill_class(:missing)}>
                      No payout set up
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Private helpers ─────────────────────────────────────────────────

  defp format_amount(nil), do: "GHS 0.00"

  defp format_amount(cents) when is_integer(cents) do
    "GHS #{div(cents, 100)}.#{String.pad_leading(to_string(rem(cents, 100)), 2, "0")}"
  end

  defp format_amount(_), do: "GHS 0.00"

  defp format_rate(nil), do: "—"
  defp format_rate(rate), do: "#{Float.round(rate * 100, 1)}%"

  defp pill_class(:ready),
    do: "inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700"

  defp pill_class(:missing),
    do: "inline-flex px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700"
end
