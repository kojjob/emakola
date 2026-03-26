defmodule EmakolaWeb.DashboardComponents do
  @moduledoc """
  Layout and general UI components for the merchant admin dashboard:
  header with period selector, alerts panel, and recent orders table.
  """

  use Phoenix.Component

  attr :period, :string, required: true
  attr :periods, :list, required: true

  def dashboard_header(assigns) do
    ~H"""
    <header class="flex flex-col sm:flex-row sm:items-end justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-slate-900">Dashboard</h1>
        <p class="text-sm text-slate-500 mt-1">Your store at a glance</p>
      </div>

      <div class="flex items-center gap-2">
        <div class="flex items-center rounded-lg border border-slate-200 bg-white p-1">
          <button
            :for={p <- @periods}
            phx-click="change_period"
            phx-value-period={p}
            class={[
              "px-3 py-1.5 text-sm font-medium rounded-md transition-colors",
              if(p == @period,
                do: "bg-blue-600 text-white",
                else: "text-slate-500 hover:text-slate-700 hover:bg-slate-50"
              )
            ]}
          >
            {period_label(p)}
          </button>
        </div>

        <button
          phx-click="refresh_data"
          class="p-2 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-lg transition-colors"
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

  attr :pending_orders, :integer, required: true
  attr :low_stock_count, :integer, required: true
  attr :failed_payments, :integer, required: true

  def alerts_panel(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-slate-200 p-5">
      <h3 class="text-sm font-semibold text-slate-900 mb-4">Needs Attention</h3>

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
    </div>
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
    <section class="bg-white rounded-xl border border-slate-200">
      <div class="flex items-center justify-between px-6 py-4 border-b border-slate-100">
        <h2 class="text-base font-semibold text-slate-900">Recent Orders</h2>
        <.link navigate="/admin/orders" class="text-sm font-medium text-blue-600 hover:text-blue-700">
          View All
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
                  <span class={[
                    "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
                    status_badge_classes(order.status)
                  ]}>
                    {Phoenix.Naming.humanize(order.status)}
                  </span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </section>
    """
  end

  defp customer_display_name(order) do
    case order do
      %{customer: %{name: name}} when is_binary(name) and name != "" -> name
      %{customer: %{email: email}} when is_binary(email) and email != "" -> email
      _ -> "Guest"
    end
  end

  defp status_badge_classes(:pending), do: "bg-amber-50 text-amber-700"
  defp status_badge_classes(:confirmed), do: "bg-blue-50 text-blue-700"
  defp status_badge_classes(:processing), do: "bg-indigo-50 text-indigo-700"
  defp status_badge_classes(:shipped), do: "bg-purple-50 text-purple-700"
  defp status_badge_classes(:delivered), do: "bg-green-50 text-green-700"
  defp status_badge_classes(:cancelled), do: "bg-red-50 text-red-700"
  defp status_badge_classes(_), do: "bg-slate-50 text-slate-700"

  defp format_money(amount_pesewas, currency \\ "GHS") do
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
    "#{sign}#{currency} #{formatted}.#{String.pad_leading(to_string(minor), 2, "0")}"
  end
end
