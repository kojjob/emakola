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
        <.link
          :if={EmakolaWeb.AiGate.enabled?()}
          navigate="/admin/products/snap"
          class="inline-flex items-center justify-center gap-2 font-semibold transition-colors rounded-control cursor-pointer px-3 py-1.5 text-xs bg-primary hover:bg-primary-hover text-white"
        >
          📸 Add by photo
        </.link>

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

  defp period_label("today"), do: "Today"
  defp period_label("week"), do: "7 Days"
  defp period_label("month"), do: "30 Days"
  defp period_label("all"), do: "All Time"
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

  def work_queue(assigns) do
    ~H"""
    <.admin_card padding={:none} class="p-5">
      <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">Do these now</h2>

      <div class="divide-y divide-slate-100">
        <.work_queue_row
          :if={@pending_orders > 0}
          id="work-queue-orders"
          icon="hero-shopping-bag"
          icon_class="bg-warning-soft text-warning"
          label="Confirm new orders"
          count={@pending_orders}
          action="Confirm"
          href="/admin/orders"
        />
        <.work_queue_row
          :if={@sold_out_count > 0}
          id="work-queue-stock"
          icon="hero-cube"
          icon_class="bg-danger-soft text-danger"
          label="Restock sold-out items"
          count={@sold_out_count}
          action="Restock"
          href="/admin/inventory"
        />
        <.work_queue_row
          :if={@open_returns > 0}
          id="work-queue-returns"
          icon="hero-arrow-uturn-left"
          icon_class="bg-info-soft text-info"
          label="Review return requests"
          count={@open_returns}
          action="Review"
          href="/admin/returns"
        />
      </div>

      <div
        :if={@pending_orders == 0 and @sold_out_count == 0 and @open_returns == 0}
        id="work-queue-all-clear"
        class="flex items-center gap-3 py-2"
      >
        <div class="w-10 h-10 rounded-full bg-success-soft flex items-center justify-center shrink-0">
          <.icon name="hero-check" class="size-5 text-success" />
        </div>
        <p class="text-sm font-medium text-slate-700">Nothing to do — nice work</p>
      </div>
    </.admin_card>
    """
  end

  attr :id, :string, required: true
  attr :icon, :string, required: true
  attr :icon_class, :string, required: true
  attr :label, :string, required: true
  attr :count, :integer, required: true
  attr :action, :string, required: true
  attr :href, :string, required: true

  defp work_queue_row(assigns) do
    ~H"""
    <div id={@id} class="flex items-center gap-3 py-3">
      <div class={["w-10 h-10 rounded-full flex items-center justify-center shrink-0", @icon_class]}>
        <.icon name={@icon} class="size-5" />
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-semibold text-slate-900 truncate">{@label}</p>
        <p class="text-xs text-slate-500 tabular-nums">{@count} waiting</p>
      </div>
      <.link
        navigate={@href}
        class="shrink-0 inline-flex items-center px-3 py-1.5 rounded-control bg-primary hover:bg-primary-hover text-white text-xs font-semibold transition-colors"
      >
        {@action}
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
          <p class="text-xs text-slate-500 tabular-nums">{product.quantity} sold</p>
        </div>
      </div>
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
    <.admin_card padding={:none} class="overflow-hidden">
      <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
        <div class="flex items-center gap-2">
          <span class="material-symbols-outlined text-xl text-primary">receipt_long</span>
          <h2 class="text-base font-bold text-slate-800">Recent Orders</h2>
        </div>
        <.link
          navigate="/admin/orders"
          class="inline-flex items-center gap-1 text-sm font-medium text-primary hover:text-primary-hover"
        >
          View all <span class="material-symbols-outlined text-base">arrow_forward</span>
        </.link>
      </div>

      <%= if @recent_orders == [] do %>
        <div class="px-6 py-16 text-center">
          <span class="material-symbols-outlined text-4xl text-slate-200 mb-3 block">
            receipt_long
          </span>
          <p class="text-sm font-medium text-slate-500">No orders yet</p>
          <p class="text-xs text-slate-400 mt-1">Orders will appear here as customers place them</p>
        </div>
      <% else %>
        <div class="overflow-x-auto">
          <table class="w-full">
            <thead>
              <tr class="border-b border-slate-100">
                <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Order
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Customer
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Total
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-slate-500 uppercase tracking-wider">
                  Status
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-50">
              <tr :for={order <- @recent_orders} class="hover:bg-slate-50 transition-colors">
                <td class="px-6 py-3">
                  <.link
                    navigate={"/admin/orders/#{order.id}"}
                    class="text-sm font-medium text-blue-600 hover:text-blue-700"
                  >
                    {order.order_number}
                  </.link>
                </td>
                <td class="px-6 py-3 text-sm text-slate-600">
                  {customer_display_name(order)}
                </td>
                <td class="px-6 py-3 text-sm text-slate-900 font-medium text-right tabular-nums">
                  {format_money(order.total)}
                </td>
                <td class="px-6 py-3 text-right">
                  <.status_badge status={order.status} variant={:order} />
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </.admin_card>
    """
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
