defmodule EmakolaWeb.DashboardMetricComponents do
  @moduledoc """
  KPI cards and chart card components for the merchant admin dashboard.
  """

  use Phoenix.Component

  import EmakolaWeb.AdminComponents, only: [admin_card: 1, stat_card: 1]
  import EmakolaWeb.CoreComponents, only: [icon: 1]

  attr :total_revenue, :integer, required: true
  attr :revenue_change, :float, default: nil
  attr :order_count, :integer, required: true
  attr :orders_change, :float, default: nil
  attr :customer_count, :integer, required: true
  attr :customers_change, :float, default: nil
  attr :avg_order_value, :integer, required: true
  attr :aov_change, :float, default: nil

  # True until the LiveView socket connects. The dead render has no data yet
  # (the ~12 dashboard queries are deferred to the connected mount), so the
  # values below are all zero — and "Revenue GHS 0.00" is indistinguishable
  # from "you have made no sales". Show a skeleton instead of a wrong number.
  attr :loading, :boolean, default: false

  def kpi_cards(assigns) do
    ~H"""
    <section class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <.kpi_card
        label="Revenue"
        icon="hero-banknotes"
        tone={:primary}
        value={format_money(@total_revenue)}
        loading={@loading}
        change={@revenue_change}
      />
      <.kpi_card
        label="Orders"
        icon="hero-shopping-bag"
        tone={:info}
        value={Integer.to_string(@order_count)}
        loading={@loading}
        change={@orders_change}
      />
      <.kpi_card
        label="Customers"
        icon="hero-users"
        tone={:info}
        value={Integer.to_string(@customer_count)}
        loading={@loading}
        change={@customers_change}
      />
      <.kpi_card
        label="Avg Order"
        icon="hero-arrow-trending-up"
        tone={:neutral}
        value={format_money(@avg_order_value)}
        loading={@loading}
        change={@aov_change}
      />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :value, :string, required: true
  attr :change, :float, default: nil
  attr :loading, :boolean, default: false
  attr :tone, :atom, default: :neutral

  defp kpi_card(%{loading: true} = assigns) do
    ~H"""
    <.stat_card label={@label} value="" tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
      <:delta>
        <div class="mt-2 h-7 w-24 rounded bg-slate-200 animate-pulse" aria-hidden="true"></div>
        <span class="sr-only">Loading {@label}</span>
      </:delta>
    </.stat_card>
    """
  end

  defp kpi_card(assigns) do
    ~H"""
    <.stat_card label={@label} value={@value} tone={@tone}>
      <:icon><.icon name={@icon} class="size-7" /></:icon>
      <:delta>
        <.change_indicator change={@change} />
      </:delta>
    </.stat_card>
    """
  end

  attr :change, :float, default: nil

  defp change_indicator(%{change: nil} = assigns) do
    ~H"""
    <p class="text-xs text-slate-400 mt-2">No previous data</p>
    """
  end

  defp change_indicator(%{change: change} = assigns) when change >= 0 do
    ~H"""
    <div class="flex items-center gap-1 mt-2">
      <.icon name="hero-arrow-up" class="size-3.5 text-green-600" />
      <span class="text-xs font-medium text-green-600">{abs(@change)}%</span>
      <span class="text-xs text-slate-400">vs prev period</span>
    </div>
    """
  end

  defp change_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-1 mt-2">
      <.icon name="hero-arrow-down" class="size-3.5 text-red-600" />
      <span class="text-xs font-medium text-red-600">{abs(@change)}%</span>
      <span class="text-xs text-slate-400">vs prev period</span>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :chart_type, :string, required: true
  attr :chart_data, :map, required: true
  attr :height, :string, default: "h-64"

  def chart_card(assigns) do
    ~H"""
    <.admin_card padding={:none} class="p-5">
      <div class="flex items-center gap-2 mb-4">
        <.icon name="hero-chart-bar" class="size-5 text-primary" />
        <h3 class="text-base font-bold text-slate-800">{@title}</h3>
      </div>
      <div class={@height}>
        <canvas
          id={@id}
          phx-hook="ChartHook"
          phx-update="ignore"
          data-chart-type={@chart_type}
          data-chart-data={Jason.encode!(@chart_data)}
          class="w-full h-full"
        />
      </div>
    </.admin_card>
    """
  end

  defp format_money(amount_pesewas) do
    major = amount_pesewas |> div(100) |> abs() |> Emakola.Money.group_thousands()
    minor = rem(abs(amount_pesewas), 100)
    sign = if amount_pesewas < 0, do: "-", else: ""
    "#{sign}GHS #{major}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end
end
