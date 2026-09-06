defmodule EmakolaWeb.DashboardComponents do
  @moduledoc """
  Layout and general UI components for the merchant admin dashboard:
  header with period selector, alerts panel, and recent orders table.
  """

  use Phoenix.Component

  import EmakolaWeb.AdminComponents, only: [admin_card: 1, status_badge: 1]
  import EmakolaWeb.CoreComponents, only: [icon: 1]

  attr :period, :string, required: true
  attr :periods, :list, required: true
  attr :greeting, :string, default: "Maakye"
  attr :merchant_name, :string, default: nil

  def dashboard_header(assigns) do
    ~H"""
    <header class="flex flex-col sm:flex-row sm:items-end justify-between gap-4 pt-2">
      <div>
        <h1 id="dashboard-greeting" class="text-2xl sm:text-3xl font-bold text-slate-900">
          {@greeting}<span :if={@merchant_name}>, {@merchant_name}</span>
        </h1>
        <p class="text-sm text-slate-500 mt-1">Your store at a glance</p>
      </div>

      <div class="flex items-center gap-2">
        <div class="flex items-center rounded-control bg-surface shadow-sm p-1">
          <button
            :for={p <- @periods}
            phx-click="change_period"
            phx-value-period={p}
            class={[
              "px-3 py-1.5 text-sm font-medium rounded-lg transition-colors",
              if(p == @period,
                do: "bg-primary text-white shadow-sm",
                else: "text-slate-500 hover:text-slate-700 hover:bg-slate-50"
              )
            ]}
          >
            {period_label(p)}
          </button>
        </div>

        <button
          phx-click="refresh_data"
          class="p-2 text-slate-400 hover:text-primary hover:bg-surface hover:shadow-sm rounded-control transition-all"
          title="Refresh dashboard"
        >
          <span class="material-symbols-outlined text-xl">refresh</span>
        </button>
      </div>
    </header>
    """
  end

  # Words a merchant says, not analyst ranges.
  defp period_label("today"), do: "Today"
  defp period_label("week"), do: "This week"
  defp period_label("month"), do: "This month"
  defp period_label("all"), do: "All time"
  defp period_label(other), do: other

  @doc """
  "Do these now" — the day's work as a short list of actions, each with a
  count and a one-tap button to the page that resolves it.

  A merchant who reads slowly should not have to interpret four charts to
  learn what to do next. Rows with nothing to do disappear rather than
  showing a zero, so the list only ever contains real work; when it empties,
  an all-clear takes its place.
  """
  attr :pending_orders, :integer, required: true
  attr :sold_out_count, :integer, required: true
  attr :open_returns, :integer, required: true
  attr :suppliers_to_chase, :integer, default: 0

  def work_queue(assigns) do
    ~H"""
    <section :if={
      @pending_orders > 0 or @sold_out_count > 0 or @open_returns > 0 or
        @suppliers_to_chase > 0
    }>
      <div class="grid grid-cols-1 md:grid-cols-[repeat(auto-fit,minmax(300px,1fr))] gap-4">
        <.work_tile
          :if={@pending_orders > 0}
          id="work-queue-orders"
          icon="hero-shopping-bag"
          tint="bg-primary-soft text-primary"
          edge="shadow-[inset_4px_0_0_theme(colors.emerald.600)]"
          label="Orders to send"
          count={@pending_orders}
          action="Send"
          href="/admin/orders"
        />
        <.work_tile
          :if={@sold_out_count > 0}
          id="work-queue-stock"
          icon="hero-cube"
          tint="bg-amber-100 text-amber-600"
          edge="shadow-[inset_4px_0_0_theme(colors.amber.600)]"
          label="Items sold out"
          count={@sold_out_count}
          action="Restock"
          href="/admin/inventory"
        />
        <%!-- The SLA clock escalates in the background; without a tile here
              the merchant only finds out by opening an order. --%>
        <.work_tile
          :if={@suppliers_to_chase > 0}
          id="work-queue-suppliers"
          icon="hero-clock"
          tint="bg-rose-100 text-rose-600"
          edge="shadow-[inset_4px_0_0_theme(colors.rose.600)]"
          label="Suppliers not replying"
          count={@suppliers_to_chase}
          action="Check"
          href="/admin/orders"
        />
        <.work_tile
          :if={@open_returns > 0}
          id="work-queue-returns"
          icon="hero-arrow-uturn-left"
          tint="bg-rose-100 text-rose-600"
          edge="shadow-[inset_4px_0_0_theme(colors.rose.600)]"
          label="Returns to answer"
          count={@open_returns}
          action="Answer"
          href="/admin/returns"
        />
      </div>
    </section>

    <div
      :if={
        @pending_orders == 0 and @sold_out_count == 0 and @open_returns == 0 and
          @suppliers_to_chase == 0
      }
      id="work-queue-all-clear"
      class="flex items-center gap-4 rounded-card border border-border bg-surface px-6 py-4"
    >
      <div class="flex size-11 shrink-0 items-center justify-center rounded-full bg-success-soft">
        <.icon name="hero-check" class="size-5 text-success" />
      </div>
      <div class="flex-1">
        <p class="text-sm font-bold text-slate-900">Nothing to do — nice work</p>
        <p class="text-xs text-slate-500 mt-0.5">New orders and questions show here.</p>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :tint, :string, required: true
  attr :edge, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :action, :string, required: true
  attr :href, :string, required: true

  defp work_tile(assigns) do
    ~H"""
    <div
      id={@id}
      class={["flex items-center gap-4 rounded-card border border-border bg-surface p-5", @edge]}
    >
      <div class={["flex size-[52px] shrink-0 items-center justify-center rounded-card", @tint]}>
        <.icon name={@icon} class="size-6" />
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-[26px] leading-none font-black text-slate-900 tabular-nums">{@count}</p>
        <p class="mt-1 text-[13px] font-bold text-slate-700 truncate">{@label}</p>
      </div>
      <.link
        navigate={@href}
        class="inline-flex shrink-0 items-center gap-1.5 rounded-control bg-primary px-4 py-2.5 text-xs font-bold text-white transition-colors hover:bg-primary-hover"
      >
        {@action} <.icon name="hero-arrow-right" class="size-3" />
      </.link>
    </div>
    """
  end

  @doc """
  Best sellers as photo cards — merchants recognize their own stock by
  picture faster than by name.
  """
  attr :best_sellers, :list, required: true

  def best_sellers_panel(assigns) do
    ~H"""
    <.admin_card :if={@best_sellers != []} id="best-sellers" padding={:none} class="p-5">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide">Best sellers</h2>
        <.link navigate="/admin/products" class="text-xs font-semibold text-primary hover:underline">
          See all
        </.link>
      </div>

      <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
        <div :for={product <- @best_sellers} class="min-w-0">
          <div class="aspect-square rounded-card bg-slate-100 overflow-hidden flex items-center justify-center">
            <img
              :if={product.image_url}
              src={product.image_url}
              alt={product.title}
              class="w-full h-full object-cover"
              loading="lazy"
            />
            <.icon :if={!product.image_url} name="hero-photo" class="size-6 text-slate-400" />
          </div>
          <p class="mt-2 text-sm font-medium text-slate-900 truncate">{product.title}</p>
          <span class="mt-1 inline-flex rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-extrabold text-emerald-700 tabular-nums">
            {product.quantity} sold
          </span>
        </div>
      </div>
    </.admin_card>
    """
  end

  attr :top_sources, :list, required: true

  def top_sources_panel(assigns) do
    ~H"""
    <.admin_card :if={@top_sources != []} id="top-sources" padding={:none} class="p-5">
      <h3 class="text-sm font-bold text-slate-800">Where orders came from</h3>
      <p class="text-sm text-slate-500 mt-1">Paid orders in this period</p>
      <ul class="mt-3 space-y-2">
        <li :for={row <- @top_sources} class="flex items-center justify-between text-sm">
          <span class="text-slate-700">{row.label}</span>
          <span class="font-mono text-slate-500">{Emakola.Plural.count(row.orders, "order")}</span>
        </li>
      </ul>
    </.admin_card>
    """
  end

  attr :pending_orders, :integer, required: true
  attr :low_stock_count, :integer, required: true
  attr :failed_payments, :integer, required: true

  def alerts_panel(assigns) do
    ~H"""
    <.admin_card padding={:none} class="p-5">
      <div class="flex items-center gap-2 mb-4">
        <span class="material-symbols-outlined text-xl text-primary">notifications_active</span>
        <h3 class="text-base font-bold text-slate-800">Needs Attention</h3>
      </div>

      <div class="space-y-1">
        <.alert_row
          icon="pending_actions"
          label="Pending Orders"
          count={@pending_orders}
          href="/admin/orders?status=pending"
          color="amber"
        />
        <.alert_row
          icon="inventory_2"
          label="Low Stock Items"
          count={@low_stock_count}
          href="/admin/products"
          color="red"
        />
        <.alert_row
          icon="error_outline"
          label="Failed Payments"
          count={@failed_payments}
          href="/admin/payments?status=failed"
          color="rose"
        />
      </div>
    </.admin_card>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :href, :string, required: true
  attr :color, :string, required: true

  defp alert_row(assigns) do
    ~H"""
    <.link
      navigate={@href}
      class="flex items-center justify-between px-3 py-2.5 rounded-lg hover:bg-slate-50 transition-colors group"
    >
      <div class="flex items-center gap-3">
        <span class={[
          "material-symbols-outlined text-lg",
          alert_icon_color(@color)
        ]}>
          {@icon}
        </span>
        <span class="text-sm text-slate-600 group-hover:text-slate-900">{@label}</span>
      </div>
      <span class={[
        "text-sm font-semibold tabular-nums",
        alert_count_color(@color, @count)
      ]}>
        {@count}
      </span>
    </.link>
    """
  end

  defp alert_icon_color("amber"), do: "text-amber-500"
  defp alert_icon_color("red"), do: "text-red-500"
  defp alert_icon_color("rose"), do: "text-rose-500"
  defp alert_icon_color(_), do: "text-slate-400"

  defp alert_count_color(_color, 0), do: "text-slate-300"
  defp alert_count_color("amber", _), do: "text-amber-600"
  defp alert_count_color("red", _), do: "text-red-600"
  defp alert_count_color("rose", _), do: "text-rose-600"
  defp alert_count_color(_, _), do: "text-slate-600"

  attr :recent_orders, :list, required: true

  def recent_orders_table(assigns) do
    ~H"""
    <.admin_card padding={:none} class="p-5 sm:p-6">
      <div class="flex items-baseline justify-between">
        <h2 class="text-[15px] font-extrabold text-slate-900">Latest orders</h2>
        <.link
          navigate="/admin/orders"
          class="inline-flex items-center gap-1.5 text-xs font-bold text-primary hover:text-primary-hover"
        >
          See all <.icon name="hero-arrow-right" class="size-3" />
        </.link>
      </div>

      <div :if={@recent_orders == []} class="py-12 text-center">
        <div class="mx-auto mb-3 flex size-12 items-center justify-center rounded-full bg-slate-50">
          <.icon name="hero-shopping-bag" class="size-6 text-slate-300" />
        </div>
        <p class="text-sm font-semibold text-slate-500">No orders yet</p>
        <p class="mt-1 text-xs text-slate-400">Orders show here as buyers place them</p>
      </div>

      <div :if={@recent_orders != []} class="mt-2 divide-y divide-slate-50">
        <.link
          :for={order <- @recent_orders}
          navigate={"/admin/orders/#{order.id}"}
          class="flex items-center gap-3.5 py-3 transition-colors hover:bg-slate-50/60"
        >
          <div class="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary-soft text-xs font-bold text-emerald-700">
            {buyer_initials(order)}
          </div>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-bold text-slate-900">{customer_display_name(order)}</p>
            <p class="text-xs text-slate-400">
              {order.order_number} · {EmakolaWeb.LayoutHelpers.relative_time(order.inserted_at)}
            </p>
          </div>
          <p class="shrink-0 text-[15px] font-extrabold text-slate-900 tabular-nums">
            {format_money(order.total)}
          </p>
          <.status_badge status={order.status} variant={:order} />
        </.link>
      </div>
    </.admin_card>
    """
  end

  defp buyer_initials(order) do
    order
    |> customer_display_name()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  defp customer_display_name(order) do
    case order do
      %{customer: %{name: name}} when is_binary(name) and name != "" -> name
      %{customer: %{email: email}} when is_binary(email) and email != "" -> email
      _ -> "Guest"
    end
  end

  defp format_money(amount_pesewas, currency \\ "GHS") do
    major = amount_pesewas |> div(100) |> abs() |> Emakola.Money.group_thousands()
    minor = rem(abs(amount_pesewas), 100)
    sign = if amount_pesewas < 0, do: "-", else: ""
    "#{sign}#{currency} #{major}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end
end
