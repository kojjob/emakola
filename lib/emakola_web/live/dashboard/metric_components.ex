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

  @doc """
  The headline money row: one big revenue card and two count tiles.

  Built for merchants who read slowly — no percentages, no four-card grid.
  Direction is an arrow plus a short sentence ("More than last week"); the
  precise deltas stay available under "See more numbers".
  """
  attr :period, :string, required: true
  attr :total_revenue, :integer, required: true
  attr :revenue_change, :float, default: nil
  attr :order_count, :integer, required: true
  attr :orders_change, :float, default: nil
  attr :customer_count, :integer, required: true
  attr :customers_change, :float, default: nil
  attr :loading, :boolean, default: false

  def money_row(assigns) do
    ~H"""
    <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <div id="money-made">
        <.stat_card
          label="Money made"
          value={if @loading, do: "…", else: format_money(@total_revenue)}
          tone={:success}
        >
          <:icon><.icon name="hero-banknotes" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">
              {comparison(@period, @revenue_change) || "What buyers paid you"}
            </p>
          </:delta>
        </.stat_card>
      </div>
      <div id="money-orders">
        <.stat_card
          label="Orders"
          value={if @loading, do: "…", else: to_string(@order_count)}
          tone={:accent}
        >
          <:icon><.icon name="hero-shopping-bag" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">
              {comparison(@period, @orders_change) || "Sales in this period"}
            </p>
          </:delta>
        </.stat_card>
      </div>
      <div id="money-buyers">
        <.stat_card
          label="Buyers"
          value={if @loading, do: "…", else: to_string(@customer_count)}
          tone={:warning}
        >
          <:icon><.icon name="hero-user-group" class="size-7" /></:icon>
          <:delta>
            <p class="text-sm text-slate-500">
              {comparison(@period, @customers_change) || "People who bought"}
            </p>
          </:delta>
        </.stat_card>
      </div>
    </section>
    """
  end

  # A sentence, not a percentage. "All time" has nothing to compare against.
  defp comparison(_period, nil), do: nil
  defp comparison(_period, change) when change == 0.0, do: nil
  defp comparison("today", change), do: more_or_less(change, "yesterday")
  defp comparison("week", change), do: more_or_less(change, "last week")
  defp comparison("month", change), do: more_or_less(change, "last month")
  defp comparison(_period, _change), do: nil

  defp more_or_less(change, base) when change > 0, do: "More than " <> base
  defp more_or_less(_change, base), do: "Less than " <> base

  @doc """
  Revenue as plain HTML bars — no chart library, no axes to decode.
  The best bar is solid emerald and carries its amount; a sentence under
  the chart says the same thing in words.
  """
  attr :id, :string, default: "money-bars"
  attr :chart, :map, required: true, doc: "%{labels: [...], values: [pesewas...]}"
  attr :loading, :boolean, default: false

  def money_bars(assigns) do
    values = assigns.chart.values
    max_value = Enum.max(values, fn -> 0 end)
    best_index = if max_value > 0, do: Enum.find_index(values, &(&1 == max_value)), else: nil

    bars =
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        %{
          index: index,
          label: Enum.at(assigns.chart.labels, index),
          # Zero days keep a 4% stub so the week reads as a row of days.
          height: if(max_value > 0, do: max(round(value / max_value * 100), 4), else: 4),
          best?: index == best_index
        }
      end)

    assigns =
      assigns
      |> assign(:bars, bars)
      |> assign(:best, best_index && Enum.at(bars, best_index))
      |> assign(:show_labels?, length(values) <= 7)
      |> assign(:has_sales?, max_value > 0)

    ~H"""
    <section id={@id} class="rounded-card border border-border bg-surface p-6">
      <div class="flex items-baseline justify-between">
        <h2 class="text-[15px] font-extrabold text-slate-900">Money each day</h2>
      </div>

      <div :if={@loading} class="mt-4 flex h-44 items-end gap-2">
        <div
          :for={height <- [40, 60, 45, 75, 55, 90, 65]}
          class="flex-1 animate-pulse rounded-t-lg bg-slate-100"
          style={"height: #{height}%"}
        >
        </div>
      </div>

      <div :if={!@loading && @has_sales?} class="mt-4 flex h-44 items-end gap-2">
        <div
          :for={bar <- @bars}
          class="flex h-full flex-1 flex-col items-center justify-end gap-1.5 min-w-0"
        >
          <span :if={bar.best?} class="text-[11px] font-extrabold text-emerald-700 whitespace-nowrap">
            {format_money(Enum.at(@chart.values, bar.index))}
          </span>
          <div
            class={[
              "w-full rounded-t-lg",
              if(bar.best?, do: "bg-emerald-600", else: "bg-emerald-200")
            ]}
            style={"height: #{bar.height}%"}
          >
          </div>
          <span
            :if={@show_labels? || bar.best?}
            class={[
              "text-[11px] font-bold whitespace-nowrap",
              if(bar.best?, do: "text-emerald-700", else: "text-slate-400")
            ]}
          >
            {bar.label}
          </span>
        </div>
      </div>
      <p :if={!@loading && @has_sales? && @best} class="mt-3 text-xs text-slate-400">
        {@best.label} made the most money.
      </p>

      <div
        :if={!@loading && !@has_sales?}
        class="mt-4 flex h-44 flex-col items-center justify-center gap-2"
      >
        <.icon name="hero-banknotes" class="size-7 text-slate-200" />
        <p class="text-sm text-slate-400">No sales in this period yet.</p>
      </div>
    </section>
    """
  end

  defp format_money(amount_pesewas) do
    major = amount_pesewas |> div(100) |> abs() |> Emakola.Money.group_thousands()
    minor = rem(abs(amount_pesewas), 100)
    sign = if amount_pesewas < 0, do: "-", else: ""
    "#{sign}GHS #{major}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end
end
