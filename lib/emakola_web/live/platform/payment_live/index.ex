defmodule EmakolaWeb.Platform.PaymentLive.Index do
  @moduledoc "Read-only platform payments & reconciliation overview."
  use EmakolaWeb, :live_view

  alias Emakola.Platform.Stats

  on_mount {EmakolaWeb.Hooks.RequirePermission, :manage_billing}

  @payment_gateways [:paystack, :hubtel]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Payments")
      |> assign(:active_nav, :payments)

    socket =
      if connected?(socket) do
        load(socket)
      else
        assign(socket,
          loaded: false,
          stats: nil,
          success_rate: nil,
          gateways: [],
          failed: nil,
          refunds: nil
        )
      end

    {:ok, socket}
  end

  defp load(socket) do
    success = Stats.successful_payment_count()
    failed_count = Stats.failed_payment_count()
    total = Stats.total_payments()
    gmv = Stats.total_gmv()
    refunded_total = Stats.total_refunded()

    success_rate =
      if success + failed_count > 0 do
        success / (success + failed_count)
      else
        nil
      end

    socket
    |> assign(:loaded, true)
    |> assign(:stats, %{
      total: total,
      success: success,
      failed: failed_count,
      gmv: gmv,
      refunded_total: refunded_total
    })
    |> assign(:success_rate, success_rate)
    |> assign(:gateways, Stats.payment_gateway_breakdown())
    |> assign(:failed, Stats.recent_failed_payments(20))
    |> assign(:refunds, Stats.recent_refunded_payments(10))
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :gateway_list, @payment_gateways)

    ~H"""
    <div class="p-6 lg:p-8 max-w-7xl mx-auto">
      <%!-- Page header --%>
      <div class="mb-8">
        <h1 class="text-2xl font-bold text-gray-900">Payments</h1>
        <p class="text-sm text-gray-500 mt-1">Payments &amp; reconciliation across all stores</p>
      </div>

      <%= if @loaded == false do %>
        <div class="text-center py-16 text-gray-400">
          <p class="text-sm">Loading payment data…</p>
        </div>
      <% else %>
        <%!-- ── Stat strip ──────────────────────────────────────────────── --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <.stat_tile
            label="Total payments"
            value={to_string(@stats.total)}
            icon="payments"
            color="blue"
          />
          <.stat_tile
            label="Success rate"
            value={format_rate(@success_rate)}
            icon="percent"
            color="emerald"
          />
          <.stat_tile
            label="GMV"
            value={format_amount(@stats.gmv)}
            icon="trending_up"
            color="amber"
          />
          <.stat_tile
            label="Refunds"
            value={format_amount(@stats.refunded_total)}
            icon="currency_exchange"
            color="rose"
          />
        </div>

        <%!-- ── Gateway breakdown ──────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mb-8">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">Gateway breakdown</h2>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Gateway</th>
                  <th class="px-6 py-3">Success</th>
                  <th class="px-6 py-3">Failed</th>
                  <th class="px-6 py-3">Volume</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :for={gw <- @gateway_list} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 font-medium text-gray-900">{humanize(gw)}</td>
                  <% gw_stats =
                    @gateways[gw] || %{success_count: 0, failed_count: 0, success_volume: 0} %>
                  <td class="px-6 py-4 text-emerald-600">{gw_stats.success_count}</td>
                  <td class="px-6 py-4 text-rose-600">{gw_stats.failed_count}</td>
                  <td class="px-6 py-4 text-gray-700">{format_amount(gw_stats.success_volume)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- ── Failed payments worklist ───────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden mb-8">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">Failed payments</h2>
            <p class="text-xs text-gray-400 mt-0.5">Most recent 20 — needs reconciliation</p>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Customer</th>
                  <th class="px-6 py-3">Amount</th>
                  <th class="px-6 py-3">Gateway</th>
                  <th class="px-6 py-3">Date</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :if={@failed == []}>
                  <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                    No failed payments — nothing to reconcile.
                  </td>
                </tr>
                <tr :for={pay <- @failed} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm text-gray-700">
                    {(pay.store && pay.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-700">{pay.customer_email || "—"}</td>
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {format_amount(pay.amount)}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">{humanize(pay.gateway)}</td>
                  <td class="px-6 py-4 text-sm text-gray-400">{date_str(pay.inserted_at)}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- ── Recent refunds ─────────────────────────────────────────── --%>
        <div class="bg-white rounded-2xl border border-gray-200 shadow-sm overflow-hidden">
          <div class="px-6 py-4 border-b border-gray-100">
            <h2 class="text-lg font-semibold text-gray-900">Recent refunds</h2>
            <p class="text-xs text-gray-400 mt-0.5">Most recent 10</p>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full">
              <thead>
                <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                  <th class="px-6 py-3">Store</th>
                  <th class="px-6 py-3">Customer</th>
                  <th class="px-6 py-3">Refunded</th>
                  <th class="px-6 py-3">Gateway</th>
                  <th class="px-6 py-3">Date</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-gray-100">
                <tr :if={@refunds == []}>
                  <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                    No refunds recorded.
                  </td>
                </tr>
                <tr :for={pay <- @refunds} class="hover:bg-gray-50 transition-colors">
                  <td class="px-6 py-4 text-sm text-gray-700">
                    {(pay.store && pay.store.name) || "—"}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-700">{pay.customer_email || "—"}</td>
                  <td class="px-6 py-4 text-sm font-medium text-gray-900">
                    {format_amount(pay.refunded_amount)}
                  </td>
                  <td class="px-6 py-4 text-sm text-gray-500">{humanize(pay.gateway)}</td>
                  <td class="px-6 py-4 text-sm text-gray-400">{date_str(pay.inserted_at)}</td>
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
  defp format_rate(rate), do: "#{round(rate * 100)}%"

  defp date_str(nil), do: "—"
  defp date_str(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp date_str(_), do: "—"

  defp humanize(:paystack), do: "Paystack"
  defp humanize(:hubtel), do: "Hubtel"
  defp humanize(:success), do: "Success"
  defp humanize(:failed), do: "Failed"
  defp humanize(:refunded), do: "Refunded"
  defp humanize(:pending), do: "Pending"
  defp humanize(other), do: to_string(other) |> String.capitalize()
end
