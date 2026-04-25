defmodule EmakolaWeb.Admin.CustomerLive.Show do
  @moduledoc """
  Customer detail page: header info, order history, total spent,
  edit customer info, and notes placeholder.
  """
  use EmakolaWeb, :live_view

  require Ash.Query
  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case load_customer(id) do
      {:ok, customer} ->
        orders = load_orders(customer.id, customer.store_id)
        total_spent = Enum.reduce(orders, 0, fn order, acc -> acc + (order.total || 0) end)

        socket =
          socket
          |> assign(
            page_title: customer.name || "Customer",
            active_nav: :customers,
            customer: customer,
            orders: orders,
            total_spent: total_spent,
            editing: false
          )

        {:ok, socket}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Customer not found")
         |> push_navigate(to: ~p"/admin/customers")}
    end
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, editing: !socket.assigns.editing)}
  end

  @impl true
  def handle_event("save_customer", %{"customer" => params}, socket) do
    case socket.assigns.customer
         |> Ash.Changeset.for_update(:update, params)
         |> Ash.update(authorize?: false) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(customer: updated, editing: false)
         |> put_flash(:info, "Customer updated")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update customer")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Back link --%>
      <.link
        navigate={~p"/admin/customers"}
        class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700 transition-colors"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Customers
      </.link>

      <%!-- Customer Header --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
          <div class="flex items-center gap-4">
            <div class="w-14 h-14 rounded-full bg-emerald-100 flex items-center justify-center flex-shrink-0">
              <span class="text-xl font-bold text-emerald-700">
                {customer_initials(@customer.name)}
              </span>
            </div>
            <div>
              <h1 class="text-xl font-bold text-slate-900">{@customer.name || "Unnamed"}</h1>
              <p class="text-sm text-slate-500">{@customer.email}</p>
              <p :if={@customer.phone} class="text-sm text-slate-500">{@customer.phone}</p>
              <p class="text-xs text-slate-400 mt-1">
                Member since {Calendar.strftime(@customer.inserted_at, "%B %d, %Y")}
              </p>
            </div>
          </div>
          <button
            phx-click="toggle_edit"
            class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            <.icon name="hero-pencil-square" class="size-4" /> Edit
          </button>
        </div>

        <%!-- Edit form --%>
        <div :if={@editing} class="mt-6 pt-6 border-t border-slate-200">
          <.form for={%{}} phx-submit="save_customer" class="space-y-4 max-w-md">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Name</label>
              <input
                type="text"
                name="customer[name]"
                value={@customer.name}
                class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1">Phone</label>
              <input
                type="text"
                name="customer[phone]"
                value={@customer.phone}
                class="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500"
              />
            </div>
            <div class="flex gap-2">
              <button
                type="submit"
                class="px-4 py-2 bg-emerald-600 text-white rounded-lg text-sm font-medium hover:bg-emerald-700 transition-colors cursor-pointer"
              >
                Save
              </button>
              <button
                type="button"
                phx-click="toggle_edit"
                class="px-4 py-2 bg-white border border-slate-200 text-slate-700 rounded-lg text-sm font-medium hover:bg-slate-50 transition-colors cursor-pointer"
              >
                Cancel
              </button>
            </div>
          </.form>
        </div>
      </div>

      <%!-- Stats row --%>
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div class="bg-white rounded-2xl border border-slate-200 p-5">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Total Spent
          </span>
          <p class="text-2xl font-bold text-slate-900 font-mono mt-2">{format_price(@total_spent)}</p>
        </div>
        <div class="bg-white rounded-2xl border border-slate-200 p-5">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Total Orders
          </span>
          <p class="text-2xl font-bold text-slate-900 font-mono mt-2">{length(@orders)}</p>
        </div>
        <div class="bg-white rounded-2xl border border-slate-200 p-5">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Avg. Order
          </span>
          <p class="text-2xl font-bold text-slate-900 font-mono mt-2">
            {format_avg_order(@total_spent, length(@orders))}
          </p>
        </div>
      </div>

      <%!-- Order History --%>
      <div class="bg-white rounded-2xl border border-slate-200 overflow-hidden">
        <div class="px-6 py-4 border-b border-slate-100">
          <h2 class="text-base font-bold text-slate-900">Order History</h2>
        </div>
        <%= if @orders == [] do %>
          <div class="text-center py-12">
            <.icon name="hero-shopping-bag" class="size-10 mx-auto text-slate-300 mb-3" />
            <p class="text-sm text-slate-500">No orders yet</p>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-100">
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Order
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Status
                  </th>
                  <th class="text-right text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Total
                  </th>
                  <th class="text-left text-[11px] font-semibold text-slate-400 uppercase tracking-wider px-6 py-3">
                    Date
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={order <- @orders}
                  class="border-b border-slate-50 hover:bg-slate-50/50 transition-colors"
                >
                  <td class="px-6 py-3 font-mono font-medium text-slate-800">{order.order_number}</td>
                  <td class="px-6 py-3">
                    <.order_status_badge status={order.status} />
                  </td>
                  <td class="px-6 py-3 text-right font-mono font-semibold text-slate-800">
                    {format_price(order.total)}
                  </td>
                  <td class="px-6 py-3 text-slate-500">
                    {Calendar.strftime(order.inserted_at, "%d/%m/%Y")}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <%!-- Notes Section (placeholder) --%>
      <div class="bg-white rounded-2xl border border-slate-200 p-6">
        <h2 class="text-base font-bold text-slate-900 mb-4">Notes</h2>
        <div class="bg-slate-50 border border-slate-200 rounded-xl p-4">
          <p class="text-sm text-slate-400 italic">No notes yet. Notes feature coming soon.</p>
        </div>
      </div>
    </div>
    """
  end

  # ── Components ──

  attr :status, :atom, required: true

  defp order_status_badge(assigns) do
    ~H"""
    <span class={"inline-flex items-center text-xs font-semibold px-2.5 py-1 rounded-full #{status_class(@status)}"}>
      {@status |> to_string() |> String.capitalize()}
    </span>
    """
  end

  defp status_class(:pending), do: "text-amber-700 bg-amber-50"
  defp status_class(:confirmed), do: "text-blue-700 bg-blue-50"
  defp status_class(:processing), do: "text-violet-700 bg-violet-50"
  defp status_class(:shipped), do: "text-indigo-700 bg-indigo-50"
  defp status_class(:delivered), do: "text-emerald-700 bg-emerald-50"
  defp status_class(:cancelled), do: "text-red-700 bg-red-50"
  defp status_class(_), do: "text-slate-700 bg-slate-50"

  # ── Data Loading ──

  defp load_customer(id) do
    Emakola.Customers.get_customer_by_id(id, authorize?: false)
  end

  defp load_orders(customer_id, store_id) do
    Emakola.Orders.Order
    |> Ash.Query.filter(customer_id == ^customer_id and store_id == ^store_id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.read!(authorize?: false)
  rescue
    _ -> []
  end

  # ── Helpers ──

  defp customer_initials(nil), do: "?"

  defp customer_initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp format_avg_order(_total, 0), do: format_price(0)
  defp format_avg_order(total, count), do: format_price(div(total, count))
end
