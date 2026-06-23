defmodule EmakolaWeb.Platform.SecurityEventsLive do
  @moduledoc """
  Platform abuse monitor: a 24h view over the security event log — hero stat
  tiles, a top-source leaderboard with anomaly flags, and a recent-event stream.
  Gated by RequirePermission (:view_audit_log). No DB on disconnected mount.

  Distinct from `/platform/security` (self-service 2FA).
  """
  use EmakolaWeb, :live_view

  on_mount {EmakolaWeb.Hooks.RequirePermission, :view_audit_log}

  alias Emakola.Security

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Security events")
      |> assign(:active_nav, :security_events)
      |> assign(:overview, nil)

    {:ok, if(connected?(socket), do: load(socket), else: socket)}
  end

  defp load(socket), do: assign(socket, :overview, Security.overview(DateTime.utc_now()))

  defp bar_pct(_count, 0), do: 0
  defp bar_pct(count, max), do: max(round(count / max * 100), 6)

  defp type_label(:rate_limit_exceeded), do: "Rate limit"
  defp type_label(:auth_failed), do: "Auth failed"
  defp type_label(other), do: other |> to_string() |> String.replace("_", " ")

  defp type_pill(:rate_limit_exceeded), do: "bg-amber-50 text-amber-700 border-amber-200"
  defp type_pill(:auth_failed), do: "bg-red-50 text-red-700 border-red-200"
  defp type_pill(_), do: "bg-gray-50 text-gray-600 border-gray-200"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 lg:p-8 max-w-6xl mx-auto">
      <div class="mb-6">
        <h1 class="text-2xl font-bold text-gray-900">Security events</h1>
        <p class="text-sm text-gray-500 mt-1">
          Rate-limit and authentication abuse across the platform, last 24 hours.
        </p>
      </div>

      <p :if={is_nil(@overview)} class="text-sm text-gray-500">Loading…</p>

      <div :if={@overview}>
        <%!-- Hero stat tiles --%>
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          <.metric_tile
            label="Events (24h)"
            value={@overview.total}
            icon="hero-chart-bar"
            chip="bg-slate-100 text-slate-600"
          />
          <.metric_tile
            label="Rate-limit hits"
            value={@overview.by_type.rate_limit_exceeded}
            icon="hero-bolt"
            chip="bg-amber-100 text-amber-600"
          />
          <.metric_tile
            label="Failed sign-ins"
            value={@overview.by_type.auth_failed}
            icon="hero-finger-print"
            chip="bg-red-100 text-red-600"
          />
          <.metric_tile
            label="Flagged sources"
            value={@overview.anomaly_count}
            icon="hero-flag"
            chip="bg-red-100 text-red-600"
          />
        </div>

        <%!-- Empty state --%>
        <div
          :if={@overview.total == 0}
          class="rounded-2xl border border-dashed border-gray-200 bg-white p-16 text-center"
        >
          <.icon name="hero-shield-check" class="mx-auto h-12 w-12 text-emerald-400" />
          <p class="mt-4 text-lg font-semibold text-gray-900">All quiet</p>
          <p class="mt-1 text-sm text-gray-500">No security events in the last 24 hours.</p>
        </div>

        <div :if={@overview.total > 0} class="grid grid-cols-1 lg:grid-cols-5 gap-6">
          <%!-- Top source IPs leaderboard --%>
          <div class="lg:col-span-2 rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
            <h2 class="text-sm font-semibold text-gray-700 mb-4">Top source IPs</h2>
            <div :if={@overview.top_ips == []} class="text-sm text-gray-400">No IP data</div>
            <div class="space-y-3">
              <% max_ip = @overview.top_ips |> Enum.map(& &1.count) |> Enum.max(fn -> 1 end) %>
              <div :for={row <- @overview.top_ips} class="flex items-center gap-3">
                <span class="w-28 shrink-0 font-mono text-xs text-gray-600 truncate">{row.ip}</span>
                <div class="flex-1 h-2.5 rounded-full bg-gray-100 overflow-hidden">
                  <div
                    class={[
                      "h-2.5 rounded-full",
                      if(row.flagged,
                        do: "bg-gradient-to-r from-red-400 to-red-600",
                        else: "bg-gradient-to-r from-emerald-400 to-emerald-500"
                      )
                    ]}
                    style={"width: #{bar_pct(row.count, max_ip)}%"}
                  >
                  </div>
                </div>
                <span class="w-8 text-right text-sm font-semibold text-gray-700">{row.count}</span>
                <span
                  :if={row.flagged}
                  class="rounded-full bg-red-100 px-2 py-0.5 text-[10px] font-semibold uppercase tracking-wide text-red-700"
                >
                  flag
                </span>
              </div>
            </div>
          </div>

          <%!-- Recent events --%>
          <div class="lg:col-span-3 rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden">
            <h2 class="text-sm font-semibold text-gray-700 px-6 pt-6 pb-3">Recent events</h2>
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead>
                  <tr class="text-left text-xs font-medium text-gray-500 uppercase tracking-wider bg-gray-50">
                    <th class="px-6 py-3">Time</th>
                    <th class="px-6 py-3">Type</th>
                    <th class="px-6 py-3">Source</th>
                    <th class="px-6 py-3">IP</th>
                  </tr>
                </thead>
                <tbody class="divide-y divide-gray-100">
                  <tr :for={e <- @overview.recent} class="hover:bg-gray-50">
                    <td class="px-6 py-3 whitespace-nowrap text-xs text-gray-500 font-mono">
                      {Calendar.strftime(e.inserted_at, "%b %d %H:%M")}
                    </td>
                    <td class="px-6 py-3">
                      <span class={[
                        "inline-block rounded-full border px-2.5 py-0.5 text-xs font-medium",
                        type_pill(e.event_type)
                      ]}>
                        {type_label(e.event_type)}
                      </span>
                    </td>
                    <td class="px-6 py-3 text-gray-700 truncate max-w-[180px]">
                      {e.identifier || "—"}
                      <span class="text-gray-400 text-xs">({e.subject_type})</span>
                    </td>
                    <td class="px-6 py-3 font-mono text-xs text-gray-500">{e.ip || "—"}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :chip, :string, required: true

  defp metric_tile(assigns) do
    ~H"""
    <div class="rounded-2xl border border-gray-200 bg-white p-5 shadow-sm">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium text-gray-500">{@label}</span>
        <span class={["flex h-9 w-9 items-center justify-center rounded-xl", @chip]}>
          <.icon name={@icon} class="h-5 w-5" />
        </span>
      </div>
      <p class="mt-3 text-3xl font-bold text-gray-900">{@value}</p>
    </div>
    """
  end
end
