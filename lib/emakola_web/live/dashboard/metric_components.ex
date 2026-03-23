defmodule EmakolaWeb.DashboardMetricComponents do
  @moduledoc """
  Metric and chart card components for the admin dashboard:
  API usage, orders activity, quota, and platform health cards.
  """

  use Phoenix.Component

  attr :token_usage, :string, required: true
  attr :token_quota_pct, :integer, required: true
  attr :token_chart, :list, required: true
  attr :total_orders, :string, required: true
  attr :orders_chart, :list, required: true

  def metric_cards(assigns) do
    ~H"""
    <%!-- API Usage Card --%>
    <div class="md:col-span-4 bg-surface-container p-6 rounded-lg relative overflow-hidden group">
      <div class="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity">
        <span class="material-symbols-outlined text-6xl">storefront</span>
      </div>
      <p class="text-sm font-medium text-on-surface-variant mb-4">API Usage</p>
      <div class="flex items-baseline gap-2">
        <span class="text-5xl font-mono font-medium text-primary">{@token_usage}</span>
        <span class="text-xs font-mono text-on-surface-variant">calls</span>
      </div>
      <div class="mt-6 h-1.5 w-full bg-surface-container-highest rounded-full overflow-hidden">
        <div
          class="h-full bg-primary rounded-full transition-all duration-500"
          style={"width: #{@token_quota_pct}%"}
        >
        </div>
      </div>
      <p class="text-[10px] text-on-surface-variant mt-2 font-mono">
        {@token_quota_pct}% of plan limit
      </p>
    </div>

    <%!-- Orders Card --%>
    <div class="md:col-span-4 bg-surface-container p-6 rounded-lg">
      <p class="text-sm font-medium text-on-surface-variant mb-4">Activity</p>
      <div class="flex items-baseline gap-2">
        <span class="text-5xl font-mono font-medium text-on-surface">{@total_orders}</span>
      </div>
      <div class="mt-4 flex gap-1 items-end h-12">
        <div
          :for={h <- @orders_chart}
          class="flex-1 rounded-t-sm transition-all duration-300"
          style={"height: #{h}%; background-color: var(--fp-chart-primary); opacity: #{max(h / 100, 0.3)};"}
        >
        </div>
      </div>
    </div>

    <%!-- Quota Card --%>
    <div class="md:col-span-4 bg-surface-container p-6 rounded-lg">
      <div class="flex justify-between items-start mb-4">
        <p class="text-sm font-medium text-on-surface-variant">Quota</p>
        <span class={[
          "text-[10px] font-mono px-2 py-0.5 rounded-full",
          if(@token_quota_pct >= 80,
            do: "bg-error/10 text-error",
            else: "bg-secondary/10 text-secondary"
          )
        ]}>
          {if @token_quota_pct >= 80, do: "LIMIT NEAR", else: "ON TRACK"} {@token_quota_pct}%
        </span>
      </div>
      <span class="text-5xl font-mono font-medium text-secondary">{@token_usage}</span>
      <div class="mt-6 flex gap-1.5 h-8">
        <div
          :for={{h, opacity} <- @token_chart}
          class="flex-1 mt-auto rounded-sm transition-all duration-300"
          style={"height: #{h}%; background-color: var(--fp-chart-secondary); opacity: #{opacity};"}
        >
        </div>
      </div>
    </div>
    """
  end

  attr :avg_latency, :string, required: true
  attr :error_rate, :string, required: true
  attr :success_rate, :float, required: true
  attr :success_chart, :list, required: true

  def platform_health_card(assigns) do
    ~H"""
    <div class="md:col-span-8 bg-surface-container-low rounded-lg p-8 flex flex-col justify-between">
      <div class="flex justify-between items-start">
        <div>
          <h3 class="text-xl font-bold font-headline mb-1">Platform Health</h3>
          <p class="text-sm text-on-surface-variant">Across all activity in past 24 hours</p>
        </div>
        <div class="flex gap-4">
          <div class="text-right">
            <p class="text-xs font-mono text-on-surface-variant">AVG_LATENCY</p>
            <p class="font-mono text-primary">{@avg_latency}</p>
          </div>
          <div class="text-right">
            <p class="text-xs font-mono text-on-surface-variant">ERROR_RATE</p>
            <p class="font-mono text-error">{@error_rate}</p>
          </div>
          <div class="text-right">
            <p class="text-xs font-mono text-on-surface-variant">SUCCESS</p>
            <p class="font-mono text-primary">{@success_rate}%</p>
          </div>
        </div>
      </div>
      <div class="mt-12 relative h-48 flex items-end justify-between gap-1">
        <div
          :for={{h, i} <- Enum.with_index(@success_chart)}
          class="w-full rounded-t-lg transition-all duration-300"
          style={"height: #{h}%; background-color: var(--fp-chart-primary); opacity: #{min((i + 2) / (length(@success_chart) + 1), 1)};"}
        >
        </div>
      </div>
    </div>
    """
  end
end
