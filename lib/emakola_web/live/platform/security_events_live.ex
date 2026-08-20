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

  defp severity_family(:auth_failed), do: "red"
  defp severity_family(:rate_limit_exceeded), do: "amber"
  defp severity_family(_), do: "neutral"

  # severity_pill has no "neutral" tone — the neutral family wears slate.
  defp severity_tone(event_type) do
    case severity_family(event_type) do
      "neutral" -> "slate"
      family -> family
    end
  end

  defp rail_dot_class(event_type) do
    case severity_family(event_type) do
      "red" -> "bg-red-500"
      "amber" -> "bg-amber-500"
      "neutral" -> "bg-gray-300"
    end
  end

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
          <.stat_tile
            id="security-events-total"
            label="Events (24h)"
            value={@overview.total}
            icon="monitoring"
            color="slate"
          />
          <.stat_tile
            id="security-events-rate-limit"
            label="Rate-limit hits"
            value={@overview.by_type.rate_limit_exceeded}
            icon="bolt"
            color="amber"
          />
          <.stat_tile
            id="security-events-auth-failed"
            label="Failed sign-ins"
            value={@overview.by_type.auth_failed}
            icon="fingerprint"
            color="red"
          />
          <.stat_tile
            id="security-events-flagged"
            label="Flagged sources"
            value={@overview.anomaly_count}
            icon="flag"
            color="rose"
          />
        </div>

        <.platform_empty_state
          :if={@overview.total == 0}
          icon="hero-shield-check"
          title="All quiet"
          description="No security events in the last 24 hours."
        />

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

          <%!-- Recent events timeline --%>
          <div class="lg:col-span-3 rounded-2xl border border-gray-200 bg-white shadow-sm p-6">
            <h2 class="text-sm font-semibold text-gray-700 mb-4">Recent events</h2>
            <ol id="recent-security-events">
              <li
                :for={event <- @overview.recent}
                data-severity={severity_family(event.event_type)}
                class="relative flex gap-4 pb-5 last:pb-0"
              >
                <div class="flex flex-col items-center">
                  <span class={[
                    "mt-1 h-2.5 w-2.5 rounded-full ring-4 ring-white shrink-0",
                    rail_dot_class(event.event_type)
                  ]}>
                  </span>
                  <span class="w-px flex-1 bg-gray-100"></span>
                </div>
                <div class="min-w-0 flex-1 -mt-0.5">
                  <div class="flex flex-wrap items-center gap-x-2.5 gap-y-1">
                    <.severity_pill
                      label={type_label(event.event_type)}
                      tone={severity_tone(event.event_type)}
                    />
                    <span class="text-[13px] font-semibold text-gray-900 truncate max-w-[220px]">
                      {event.identifier || "—"}
                    </span>
                    <span class="text-[11px] text-gray-400">({event.subject_type})</span>
                  </div>
                  <p class="mt-1 font-mono text-[11px] text-gray-400">
                    {"#{Calendar.strftime(event.inserted_at, "%b %d %H:%M")} · #{event.ip || "no IP"}"}
                  </p>
                </div>
              </li>
            </ol>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
