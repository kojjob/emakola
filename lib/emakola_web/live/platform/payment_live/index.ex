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
      |> stream(:failed, [])
      |> stream(:refunds, [])

    socket =
      if connected?(socket) do
        load(socket)
      else
        assign(socket,
          loaded: false,
          stats: nil,
          success_rate: nil,
          gateways: []
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
    failed = Stats.recent_failed_payments(20)
    refunds = Stats.recent_refunded_payments(10)

    success_rate =
      if success + failed_count > 0 do
        success / (success + failed_count)
      else
        nil
      end

    socket
    |> assign(:loaded, true)
    |> assign(:gmv_trend, Stats.gmv_by_day(30))
    |> assign(:stats, %{
      total: total,
      success: success,
      failed: failed_count,
      gmv: gmv,
      refunded_total: refunded_total
    })
    |> assign(:success_rate, success_rate)
    |> assign(:gateways, Stats.payment_gateway_breakdown())
    |> stream(:failed, failed, reset: true)
    |> stream(:refunds, refunds, reset: true)
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
        <%!-- ── Hero: GMV trend + stat tiles ───────────────────────────── --%>
        <div class="grid grid-cols-1 lg:grid-cols-[1.5fr_1fr] gap-4 mb-8 items-stretch">
          <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm flex flex-col">
            <div class="flex items-start justify-between gap-3 flex-wrap">
              <div>
                <h2 class="text-[13px] font-bold text-gray-900">GMV · last 30 days</h2>
                <p class="mt-1 text-2xl font-bold text-gray-900 tabular-nums">
                  {format_amount(@stats.gmv)}
                </p>
              </div>
              <.severity_pill
                label={"Success rate #{format_rate(@success_rate)}"}
                tone="emerald"
              />
            </div>
            <div class="flex-1 min-h-36 mt-3">
              <canvas
                id="payments-gmv-chart"
                phx-hook="ChartHook"
                phx-update="ignore"
                data-chart-type="gmv-line"
                data-chart-data={Jason.encode!(@gmv_trend)}
              >
              </canvas>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-4">
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
              id="payments-failed-count"
              label="Failed"
              value={@stats.failed}
              icon="error"
              color="red"
            />
            <.stat_tile
              label="Refunds"
              value={format_amount(@stats.refunded_total)}
              icon="currency_exchange"
              color="rose"
            />
          </div>
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
              <tbody id="failed-payments" phx-update="stream" class="divide-y divide-gray-100">
                <tr id="failed-payments-empty" class="hidden only:table-row">
                  <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                    No failed payments — nothing to reconcile.
                  </td>
                </tr>
                <tr
                  :for={{id, pay} <- @streams.failed}
                  id={id}
                  class="hover:bg-gray-50 transition-colors"
                >
                  <td class="px-6 py-4 text-sm text-gray-700">
                    <span class="flex items-center gap-2.5">
                      <.store_avatar
                        :if={pay.store}
                        store={pay.store}
                        class="w-8 h-8 rounded-[9px] text-[13px]"
                      />
                      {(pay.store && pay.store.name) || "—"}
                    </span>
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
              <tbody id="recent-refunds" phx-update="stream" class="divide-y divide-gray-100">
                <tr id="recent-refunds-empty" class="hidden only:table-row">
                  <td colspan="5" class="px-6 py-12 text-center text-sm text-gray-400">
                    No refunds recorded.
                  </td>
                </tr>
                <tr
                  :for={{id, pay} <- @streams.refunds}
                  id={id}
                  class="hover:bg-gray-50 transition-colors"
                >
                  <td class="px-6 py-4 text-sm text-gray-700">
                    <span class="flex items-center gap-2.5">
                      <.store_avatar
                        :if={pay.store}
                        store={pay.store}
                        class="w-8 h-8 rounded-[9px] text-[13px]"
                      />
                      {(pay.store && pay.store.name) || "—"}
                    </span>
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
    major = cents |> div(100) |> Emakola.Money.group_thousands()
    "GHS #{major}.#{String.pad_leading(to_string(rem(cents, 100)), 2, "0")}"
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
