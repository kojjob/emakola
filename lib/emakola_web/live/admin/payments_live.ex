defmodule EmakolaWeb.Admin.PaymentsLive do
  @moduledoc """
  Payment reconciliation dashboard for the merchant admin.

  Displays summary cards (total revenue, successful/pending/failed counts)
  and a filterable table of all payments for the current store.
  Amounts stored in pesewas are displayed as GHS.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

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
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
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
        <div class="text-center py-16 bg-white rounded-2xl shadow-sm">
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
        <div class="hidden md:block bg-white rounded-2xl shadow-sm overflow-hidden">
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
            class="bg-white rounded-2xl shadow-sm p-4"
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
    <div class="bg-white rounded-2xl shadow-sm p-5">
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

  # Cap the rows materialised for the table; the summary is computed from
  # DB aggregates so totals stay accurate regardless of this cap.
  @payments_page_limit 200

  defp load_payments(socket) do
    %{store_id: store_id, status_filter: status} = socket.assigns

    assign(socket,
      payments: fetch_payments(store_id, status),
      summary: compute_summary(store_id)
    )
  end

  defp fetch_payments(store_id, status) do
    status_arg = if status == :all, do: nil, else: status

    Ash.Query.for_read(
      Emakola.Payments.Payment,
      :by_store_with_status,
      %{store_id: store_id, status: status_arg}
    )
    |> Ash.Query.limit(@payments_page_limit)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  defp compute_summary(store_id) do
    %{
      total_revenue: success_revenue(store_id),
      success_count: count_status(store_id, :success),
      pending_count: count_status(store_id, :pending),
      failed_count: count_status(store_id, :failed)
    }
  end

  defp count_status(store_id, status_value) do
    Ash.Query.for_read(
      Emakola.Payments.Payment,
      :by_store_with_status,
      %{store_id: store_id, status: status_value}
    )
    |> Ash.count(authorize?: false)
    |> case do
      {:ok, n} -> n
      _ -> 0
    end
  end

  defp success_revenue(store_id) do
    import Ecto.Query, only: [from: 2]

    from(p in Emakola.Payments.Payment,
      where: p.store_id == ^store_id and p.status == :success
    )
    |> Emakola.Repo.aggregate(:sum, :amount)
    |> to_integer_amount()
  rescue
    _ -> 0
  end

  # SUM over an integer column comes back as a Decimal from Postgres;
  # Currency.format_price/2 requires an integer (minor units).
  defp to_integer_amount(nil), do: 0
  defp to_integer_amount(%Decimal{} = d), do: Decimal.to_integer(d)
  defp to_integer_amount(n) when is_integer(n), do: n
  defp to_integer_amount(n) when is_float(n), do: round(n)

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
