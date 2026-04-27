defmodule EmakolaWeb.DashboardMetricComponents do
  @moduledoc """
  KPI cards and chart card components for the merchant admin dashboard.
  """

  use Phoenix.Component

  attr :total_revenue, :integer, required: true
  attr :revenue_change, :float, default: nil
  attr :order_count, :integer, required: true
  attr :orders_change, :float, default: nil
  attr :customer_count, :integer, required: true
  attr :customers_change, :float, default: nil
  attr :avg_order_value, :integer, required: true
  attr :aov_change, :float, default: nil

  def kpi_cards(assigns) do
    ~H"""
    <section class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <.kpi_card
        label="Revenue"
        icon="payments"
        value={format_money(@total_revenue)}
        change={@revenue_change}
      />
      <.kpi_card
        label="Orders"
        icon="shopping_cart"
        value={Integer.to_string(@order_count)}
        change={@orders_change}
      />
      <.kpi_card
        label="Customers"
        icon="group"
        value={Integer.to_string(@customer_count)}
        change={@customers_change}
      />
      <.kpi_card
        label="Avg Order"
        icon="trending_up"
        value={format_money(@avg_order_value)}
        change={@aov_change}
      />
    </section>
    """
  end

  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :value, :string, required: true
  attr :change, :float, default: nil

  defp kpi_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl shadow-sm p-5 hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-3">
        <span class="text-sm font-medium text-slate-500">{@label}</span>
        <div class="w-9 h-9 rounded-xl bg-emerald-50 flex items-center justify-center">
          <span class="material-symbols-outlined text-lg text-emerald-600">{@icon}</span>
        </div>
      </div>
      <p class="text-2xl sm:text-3xl font-bold text-slate-900 tabular-nums">{@value}</p>
      <.change_indicator change={@change} />
    </div>
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
      <span class="material-symbols-outlined text-sm text-green-600">arrow_upward</span>
      <span class="text-xs font-medium text-green-600">{abs(@change)}%</span>
      <span class="text-xs text-slate-400">vs prev period</span>
    </div>
    """
  end

  defp change_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-1 mt-2">
      <span class="material-symbols-outlined text-sm text-red-600">arrow_downward</span>
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
    <div class="bg-white rounded-2xl shadow-sm p-5">
      <div class="flex items-center gap-2 mb-4">
        <span class="material-symbols-outlined text-xl text-emerald-600">analytics</span>
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
    </div>
    """
  end

  defp format_money(amount_pesewas) do
    major = div(amount_pesewas, 100)
    minor = rem(abs(amount_pesewas), 100)

    formatted =
      major
      |> abs()
      |> Integer.to_string()
      |> String.reverse()
      |> String.replace(~r/.{3}(?=.)/, "\\0,")
      |> String.reverse()

    sign = if amount_pesewas < 0, do: "-", else: ""
    "#{sign}GHS #{formatted}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end
end
