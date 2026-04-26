defmodule EmakolaWeb.Admin.PaymentsLive do
  @moduledoc """
  Payment reconciliation dashboard for the merchant admin.

  Displays summary cards (total revenue, successful/pending/failed counts)
  and a filterable table of all payments for the current store.
  Amounts stored in pesewas are displayed as GHS.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  require Ash.Query

  @statuses [:all, :success, :pending, :failed]

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Payments",
        active_nav: :payments,
        store_id: store_id,
        status_filter: :all,
        payments: [],
        summary: %{total_revenue: 0, success_count: 0, pending_count: 0, failed_count: 0},
        statuses: @statuses
      )
      |> load_payments()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "success" -> :success
        "pending" -> :pending
        "failed" -> :failed
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom)
      |> load_payments()

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.admin_page_header title="Payments" subtitle="Track and reconcile all payment transactions" />

      <%!-- Summary Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <.summary_card
          title="Total Revenue"
          value={format_price(@summary.total_revenue, "GHS")}
          color="emerald"
        />
        <.summary_card
          title="Successful"
          value={Integer.to_string(@summary.success_count)}
          color="emerald"
        />
        <.summary_card
          title="Pending"
          value={Integer.to_string(@summary.pending_count)}
          color="amber"
        />
        <.summary_card
          title="Failed"
          value={Integer.to_string(@summary.failed_count)}
          color="red"
        />
      </div>

      <%!-- Status Filter Tabs --%>
      <div class="flex flex-wrap items-center gap-3">
        <div class="flex gap-1 bg-slate-100 rounded-xl p-1">
          <.status_tab :for={status <- @statuses} status={status} current={@status_filter} />
        </div>
      </div>

      <%!-- Payments Table --%>
      <%= if @payments == [] do %>
        <div class="text-center py-16 bg-white rounded-2xl border border-slate-200">
          <svg
            class="w-12 h-12 mx-auto text-slate-300 mb-3"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="M2.25 8.25h19.5M2.25 9h19.5m-16.5 5.25h6m-6 2.25h3m-3.75 3h15a2.25 2.25 0 002.25-2.25V6.75A2.25 2.25 0 0019.5 4.5h-15a2.25 2.25 0 00-2.25 2.25v10.5A2.25 2.25 0 004.5 19.5z"
            />
          </svg>
          <p class="text-slate-600 font-medium">No payments found</p>
          <p class="text-sm text-slate-400 mt-1">
            <%= if @status_filter != :all do %>
              Try adjusting your filters
            <% else %>
              Payments will appear here when customers complete transactions
            <% end %>
          </p>
        </div>
      <% else %>
        <%!-- Desktop Table --%>
        <div class="hidden md:block bg-white rounded-2xl border border-slate-200 overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200 bg-slate-50/50">
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Date
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Order
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Customer
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Amount
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Method
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Reference
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  :for={payment <- @payments}
                  class="hover:bg-slate-50 transition-colors"
                >
                  <td class="px-4 py-3.5 text-slate-500 whitespace-nowrap">
                    {format_datetime(payment.inserted_at)}
                  </td>
                  <td class="px-4 py-3.5">
                    <%= if payment.order do %>
                      <.link
                        navigate={~p"/admin/orders/#{payment.order_id}"}
                        class="font-mono text-xs font-medium text-emerald-600 hover:text-emerald-700"
                      >
                        {payment.order.order_number}
                      </.link>
                    <% else %>
                      <span class="text-slate-400 text-xs">—</span>
                    <% end %>
                  </td>
                  <td class="px-4 py-3.5 text-slate-700">
                    {payment.customer_email || "—"}
                  </td>
                  <td class="px-4 py-3.5 font-mono text-sm font-medium text-slate-800">
                    {format_price(payment.amount, payment.currency)}
                  </td>
                  <td class="px-4 py-3.5">
                    <span class="inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium bg-slate-100 text-slate-700 capitalize">
                      {gateway_label(payment.gateway)}
                    </span>
                  </td>
                  <td class="px-4 py-3.5">
                    <.payment_status_badge status={payment.status} />
                  </td>
                  <td class="px-4 py-3.5 font-mono text-xs text-slate-500">
                    {payment.gateway_reference || "—"}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Mobile Cards --%>
        <div class="md:hidden space-y-3">
          <div
            :for={payment <- @payments}
            class="bg-white rounded-2xl border border-slate-200 p-4"
          >
            <div class="flex items-start justify-between gap-3 mb-3">
              <div>
                <p class="text-xs text-slate-400">{format_datetime(payment.inserted_at)}</p>
                <p class="font-mono text-sm font-semibold text-slate-800 mt-1">
                  {format_price(payment.amount, payment.currency)}
                </p>
              </div>
              <.payment_status_badge status={payment.status} />
            </div>
            <div class="space-y-1 text-sm">
              <p class="text-slate-500">
                <span class="text-slate-400">Customer:</span> {payment.customer_email || "—"}
              </p>
              <p class="text-slate-500">
                <span class="text-slate-400">Method:</span> {gateway_label(payment.gateway)}
              </p>
              <p class="text-slate-500 font-mono text-xs">
                <span class="font-sans text-slate-400">Ref:</span> {payment.gateway_reference || "—"}
              </p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ── Components ──

  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :color, :string, required: true

  defp summary_card(assigns) do
    ~H"""
    <div class="bg-white rounded-2xl border border-slate-200 p-5">
      <p class="text-xs font-semibold text-slate-500 uppercase tracking-wider">{@title}</p>
      <p class={[
        "text-2xl font-bold mt-2",
        summary_color(@color)
      ]}>
        {@value}
      </p>
    </div>
    """
  end

  attr :status, :atom, required: true
  attr :current, :atom, required: true

  defp status_tab(assigns) do
    ~H"""
    <button
      phx-click="filter_status"
      phx-value-status={@status}
      class={[
        "px-3 py-1.5 text-sm font-medium rounded-lg transition-colors whitespace-nowrap",
        if(@status == @current,
          do: "bg-white text-slate-900 shadow-sm",
          else: "text-slate-500 hover:text-slate-700"
        )
      ]}
    >
      {status_label(@status)}
    </button>
    """
  end

  attr :status, :atom, required: true

  defp payment_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
      status_badge_class(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  # ── Data Loading ──

  defp load_payments(socket) do
    %{store_id: store_id, status_filter: status} = socket.assigns

    all_payments = fetch_payments(store_id)

    filtered =
      case status do
        :all -> all_payments
        filter -> Enum.filter(all_payments, &(&1.status == filter))
      end

    summary = compute_summary(all_payments)

    assign(socket, payments: filtered, summary: summary)
  end

  defp fetch_payments(store_id) do
    try do
      Emakola.Payments.Payment
      |> Ash.Query.filter(store_id == ^store_id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.load(:order)
      |> Ash.read!(authorize?: false)
    rescue
      _ -> []
    end
  end

  defp compute_summary(payments) do
    %{
      total_revenue:
        payments
        |> Enum.filter(&(&1.status == :success))
        |> Enum.reduce(0, &(&1.amount + &2)),
      success_count: Enum.count(payments, &(&1.status == :success)),
      pending_count: Enum.count(payments, &(&1.status == :pending)),
      failed_count: Enum.count(payments, &(&1.status == :failed))
    }
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp summary_color("emerald"), do: "text-emerald-600"
  defp summary_color("amber"), do: "text-amber-600"
  defp summary_color("red"), do: "text-red-600"
  defp summary_color(_), do: "text-slate-800"

  defp status_label(:all), do: "All"
  defp status_label(:success), do: "Paid"
  defp status_label(:pending), do: "Pending"
  defp status_label(:failed), do: "Failed"
  defp status_label(:refunded), do: "Refunded"
  defp status_label(_), do: "Unknown"

  defp status_badge_class(:success), do: "bg-emerald-50 text-emerald-700"
  defp status_badge_class(:pending), do: "bg-amber-50 text-amber-700"
  defp status_badge_class(:failed), do: "bg-red-50 text-red-700"
  defp status_badge_class(:refunded), do: "bg-purple-50 text-purple-700"
  defp status_badge_class(_), do: "bg-slate-50 text-slate-700"

  defp gateway_label(:paystack), do: "Paystack"
  defp gateway_label(:hubtel), do: "Hubtel"
  defp gateway_label(other), do: to_string(other)

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d/%m/%Y %H:%M")
  end

  defp format_datetime(_), do: ""
end
