defmodule EmakolaWeb.DashboardComponents do
  @moduledoc """
  Layout and general UI components for the admin dashboard:
  onboarding banner, editorial header, quick insights sidebar,
  and recent activity table.
  """

  use Phoenix.Component

  attr :onboarding_complete, :boolean, required: true
  attr :setup_banner_dismissed, :boolean, required: true

  def onboarding_banner(assigns) do
    ~H"""
    <div
      :if={not @onboarding_complete and not @setup_banner_dismissed}
      class="flex items-center justify-between gap-4 p-4 rounded-xl bg-primary/10 border border-primary/20"
    >
      <div class="flex items-center gap-3">
        <span class="material-symbols-outlined text-primary text-xl">rocket_launch</span>
        <p class="text-sm font-medium text-on-surface">
          Complete your workspace setup to get the most out of Emakola
        </p>
      </div>
      <div class="flex items-center gap-2">
        <.link
          navigate="/onboarding"
          class="primary-gradient px-4 py-2 rounded-lg text-xs font-bold whitespace-nowrap"
        >
          Complete Setup
        </.link>
        <button
          phx-click="dismiss_setup_banner"
          class="p-1 text-on-surface-variant hover:text-on-surface transition-colors"
          aria-label="Dismiss"
        >
          <span class="material-symbols-outlined text-lg">close</span>
        </button>
      </div>
    </div>
    """
  end

  attr :system_status, :atom, required: true
  attr :avg_latency, :string, required: true
  attr :current_plan_name, :string, required: true
  attr :last_sync, :string, required: true

  def editorial_header(assigns) do
    ~H"""
    <section class="flex flex-col md:flex-row md:items-end justify-between gap-4">
      <div class="space-y-1">
        <h1 class="text-4xl font-extrabold font-headline tracking-tight">Command Center</h1>
        <p class="text-on-surface-variant font-medium">
          System Health:
          <span class={if(@system_status == :nominal, do: "text-primary", else: "text-secondary")}>
            {if @system_status == :nominal, do: "Nominal", else: "Warning"}
          </span>
          • Latency: <span class="font-mono text-xs">{@avg_latency}</span>
          • Plan: <span class="font-mono text-xs text-primary">{@current_plan_name}</span>
        </p>
      </div>
      <div class="flex items-center gap-3">
        <button
          phx-click="refresh_data"
          class="p-2 text-on-surface-variant hover:text-primary transition-colors rounded-lg hover:bg-surface-container-high"
          title="Refresh"
        >
          <span class="material-symbols-outlined text-lg">refresh</span>
        </button>
        <div class="flex items-center gap-2 text-sm font-mono text-on-surface-variant bg-surface-container-low px-3 py-1.5 rounded-sm">
          <span class="w-2 h-2 rounded-full bg-secondary animate-pulse"></span>
          LAST_SYNC: {@last_sync}
        </div>
      </div>
    </section>
    """
  end

  attr :cost_grade, :string, required: true
  attr :members_count, :integer, required: true
  attr :api_uptime, :string, required: true
  attr :flags_enabled, :integer, required: true
  attr :notifications_count, :integer, required: true
  attr :token_quota_pct, :integer, required: true

  def quick_insights_sidebar(assigns) do
    ~H"""
    <div class="md:col-span-4 space-y-6">
      <div class="bg-surface-container-highest/30 p-6 rounded-lg">
        <h4 class="text-sm font-bold uppercase tracking-wider text-on-surface-variant mb-4">
          Quick Insights
        </h4>
        <div class="space-y-4">
          <div class="flex items-center justify-between">
            <span class="text-sm">Cost Efficiency</span>
            <span class="font-mono text-secondary">{@cost_grade}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm">Team Size</span>
            <span class="font-mono text-on-surface">{@members_count} members</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm">API Uptime</span>
            <span class="font-mono text-primary">{@api_uptime}</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm">Feature Flags</span>
            <span class="font-mono text-on-surface">{@flags_enabled} active</span>
          </div>
          <div class="flex items-center justify-between">
            <span class="text-sm">Notifications</span>
            <span class={[
              "font-mono",
              if(@notifications_count > 0, do: "text-secondary", else: "text-on-surface-variant")
            ]}>
              {if @notifications_count > 0,
                do: "#{@notifications_count} unread",
                else: "All clear"}
            </span>
          </div>
        </div>
      </div>

      <%!-- System Status --%>
      <div class="bg-gradient-to-br from-surface-container to-surface-container-high p-6 rounded-lg">
        <p class="text-xs font-mono text-primary mb-2">// SYSTEM_STATUS</p>
        <p class="text-sm leading-relaxed text-on-surface-variant">
          {if @token_quota_pct >= 80,
            do:
              "API usage approaching limit. Consider upgrading your plan for uninterrupted service.",
            else: "All systems operational. Your platform is running within normal parameters."}
        </p>
        <a
          href="/billing"
          class="mt-4 text-primary font-semibold text-sm hover:underline flex items-center gap-1"
        >
          {if @token_quota_pct >= 80, do: "Upgrade Plan", else: "View Billing"}
          <span class="material-symbols-outlined text-sm">arrow_forward</span>
        </a>
      </div>
    </div>
    """
  end

  attr :recent_activity, :list, required: true

  def recent_activity_table(assigns) do
    ~H"""
    <section class="space-y-4">
      <div class="flex items-center justify-between">
        <h2 class="text-2xl font-bold font-headline">Recent Activity</h2>
        <a href="/activity" class="text-sm font-medium text-primary hover:underline">View All</a>
      </div>
      <div class="bg-surface-container-lowest rounded-lg overflow-hidden">
        <%= if @recent_activity == [] do %>
          <div class="px-6 py-12 text-center text-on-surface-variant">
            <span class="material-symbols-outlined text-4xl mb-2 block opacity-30">analytics</span>
            <p class="text-sm">No activity yet</p>
            <p class="text-xs mt-1 opacity-60">Activity will appear here as you use the platform</p>
          </div>
        <% else %>
          <div class="grid grid-cols-12 gap-4 px-6 py-4 bg-surface-container/30 text-xs font-mono uppercase tracking-widest text-on-surface-variant">
            <div class="col-span-5">Event</div>
            <div class="col-span-4">Time</div>
            <div class="col-span-3">Status</div>
          </div>
          <div
            :for={row <- @recent_activity}
            class="grid grid-cols-12 gap-4 px-6 py-4 items-center hover:bg-surface-container-high/50 transition-colors"
          >
            <div class="col-span-5 flex items-center gap-3">
              <div class="w-8 h-8 rounded bg-surface-container-highest flex items-center justify-center">
                <span class="material-symbols-outlined text-lg text-primary">bolt</span>
              </div>
              <div>
                <p class="text-sm font-semibold">{row.event_name}</p>
                <p class="text-xs font-mono text-on-surface-variant">{row.source}</p>
              </div>
            </div>
            <div class="col-span-4 text-sm text-on-surface-variant font-mono">{row.timestamp}</div>
            <div class="col-span-3">
              <span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-sm bg-primary/10 text-primary text-[10px] font-bold">
                <span class="w-1.5 h-1.5 rounded-full bg-primary"></span> OK
              </span>
            </div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end
end
