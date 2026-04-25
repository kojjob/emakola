defmodule EmakolaWeb.Admin.OrderLive.Show do
  @moduledoc """
  Order detail page for the merchant admin dashboard.
  Displays order info, line items, customer details, addresses,
  and modal-based status transition confirmations.

  Design matches the Emakola delivery tracking prototype layout.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  require Ash.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Order Detail",
        active_nav: :orders,
        store_id: store_id,
        order_id: id,
        order: nil,
        payment: nil,
        tracking_number: ""
      )
      |> load_order()
      |> load_payment()

    {:ok, socket}
  end

  @impl true
  def handle_event("confirm_order", _params, socket) do
    transition_order(socket, :confirm, "Order confirmed")
  end

  @impl true
  def handle_event("start_processing", _params, socket) do
    transition_order(socket, :start_processing, "Order is now processing")
  end

  @impl true
  def handle_event("mark_shipped", _params, socket) do
    transition_order(socket, :mark_shipped, "Order marked as shipped")
  end

  @impl true
  def handle_event("mark_delivered", _params, socket) do
    transition_order(socket, :mark_delivered, "Order marked as delivered")
  end

  @impl true
  def handle_event("cancel_order", _params, socket) do
    transition_order(socket, :cancel, "Order cancelled")
  end

  @impl true
  def handle_event("update_tracking", %{"tracking_number" => tracking}, socket) do
    {:noreply, assign(socket, tracking_number: tracking)}
  end

  @impl true
  def handle_event("submit_shipped", %{"tracking_number" => tracking}, socket) do
    transition_order(socket, :mark_shipped, "Order marked as shipped",
      params: %{tracking_number: tracking}
    )
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    order = socket.assigns.order

    case Ash.update(order, %{notes: notes}, action: :update_notes) do
      {:ok, updated_order} ->
        socket =
          socket
          |> assign(order: updated_order)
          |> put_flash(:info, "Notes updated")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update notes")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Back link & Header --%>
      <div class="flex items-center gap-4">
        <.link
          navigate={~p"/admin/orders"}
          class="p-2 rounded-xl hover:bg-slate-100 transition-colors"
          aria-label="Back to orders"
        >
          <svg
            class="w-5 h-5 text-slate-500"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
          </svg>
        </.link>
        <div class="flex-1">
          <div class="flex items-center gap-3">
            <h1 class="text-xl font-bold text-slate-900">
              {if @order, do: @order.order_number, else: "Loading..."}
            </h1>
            <.order_status_badge :if={@order} status={@order.status} />
          </div>
          <p :if={@order} class="text-sm text-slate-500 mt-0.5">
            Placed {format_datetime(@order.inserted_at)}
          </p>
        </div>
      </div>

      <%= if @order do %>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Column --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Status Actions --%>
            <div class="bg-white rounded-2xl border border-slate-200 p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Order Actions
              </h2>
              <div class="flex flex-wrap gap-3">
                <button
                  :if={@order.status == :pending}
                  phx-click={show_modal("confirm-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold
                         bg-blue-600 text-white hover:bg-blue-700 transition-colors"
                >
                  Confirm Order
                </button>
                <button
                  :if={@order.status == :confirmed}
                  phx-click={show_modal("processing-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold
                         bg-indigo-600 text-white hover:bg-indigo-700 transition-colors"
                >
                  Start Processing
                </button>
                <button
                  :if={@order.status == :processing}
                  phx-click={show_modal("shipped-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold
                         bg-purple-600 text-white hover:bg-purple-700 transition-colors"
                >
                  Mark as Shipped
                </button>
                <button
                  :if={@order.status == :shipped}
                  phx-click={show_modal("delivered-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl text-sm font-semibold
                         bg-emerald-600 text-white hover:bg-emerald-700 transition-colors"
                >
                  Mark as Delivered
                </button>
                <button
                  :if={@order.status not in [:cancelled, :delivered]}
                  phx-click={show_modal("cancel-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-red-200
                         rounded-xl text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M6 18L18 6M6 6l12 12"
                    />
                  </svg>
                  Cancel Order
                </button>
              </div>
            </div>

            <%!-- Line Items --%>
            <div class="bg-white rounded-2xl border border-slate-200 overflow-hidden">
              <div class="px-5 py-4 border-b border-slate-100">
                <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide">
                  Order Items
                </h2>
              </div>

              <%= if @order.line_items && @order.line_items != [] do %>
                <div class="overflow-x-auto">
                  <table class="w-full text-sm">
                    <thead>
                      <tr class="border-b border-slate-100 bg-slate-50/50">
                        <th class="px-5 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                          Product
                        </th>
                        <th class="px-5 py-3 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                          SKU
                        </th>
                        <th class="px-5 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">
                          Qty
                        </th>
                        <th class="px-5 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">
                          Unit Price
                        </th>
                        <th class="px-5 py-3 text-right text-xs font-semibold text-slate-500 uppercase tracking-wider">
                          Total
                        </th>
                      </tr>
                    </thead>
                    <tbody class="divide-y divide-slate-100">
                      <tr :for={item <- @order.line_items}>
                        <td class="px-5 py-3 text-slate-800 font-medium">{item.product_title}</td>
                        <td class="px-5 py-3 text-slate-500 font-mono text-xs">
                          {item.variant_sku || "-"}
                        </td>
                        <td class="px-5 py-3 text-right text-slate-600">{item.quantity}</td>
                        <td class="px-5 py-3 text-right font-mono text-slate-600">
                          {format_price(item.unit_price, @order.currency)}
                        </td>
                        <td class="px-5 py-3 text-right font-mono font-medium text-slate-800">
                          {format_price(item.line_total, @order.currency)}
                        </td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <div class="px-5 py-8 text-center text-slate-400 text-sm">
                  No line items
                </div>
              <% end %>

              <%!-- Order Summary --%>
              <div class="border-t border-slate-200 px-5 py-4 space-y-2">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Subtotal</span>
                  <span class="font-mono text-slate-700">
                    {format_price(@order.subtotal, @order.currency)}
                  </span>
                </div>
                <div class="flex items-center justify-between text-sm pt-2 border-t border-slate-100">
                  <span class="font-bold text-slate-900">Total</span>
                  <span class="font-mono font-bold text-slate-900 text-base">
                    {format_price(@order.total, @order.currency)}
                  </span>
                </div>
              </div>
            </div>

            <%!-- Notes --%>
            <div class="bg-white rounded-2xl border border-slate-200 p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">
                Notes
              </h2>
              <form phx-submit="update_notes">
                <textarea
                  name="notes"
                  rows="3"
                  placeholder="Add internal notes about this order..."
                  class="w-full px-3 py-2 text-sm border border-slate-200 rounded-xl
                         focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                         focus:border-emerald-500 placeholder:text-slate-400 resize-none"
                >{@order.notes || ""}</textarea>
                <div class="flex justify-end mt-2">
                  <button
                    type="submit"
                    class="px-4 py-2 bg-emerald-600 text-white text-sm font-medium
                           rounded-xl hover:bg-emerald-700 transition-colors"
                  >
                    Save Notes
                  </button>
                </div>
              </form>
            </div>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Customer Info --%>
            <div class="bg-white rounded-2xl border border-slate-200 p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Customer
              </h2>
              <%= if @order.customer do %>
                <div class="space-y-3">
                  <div>
                    <p class="text-sm font-semibold text-slate-900">{@order.customer.name}</p>
                    <p class="text-xs text-slate-500 mt-0.5">{@order.customer.email}</p>
                    <p :if={@order.customer.phone} class="text-xs text-slate-500 mt-0.5">
                      {@order.customer.phone}
                    </p>
                  </div>
                </div>
              <% else %>
                <p class="text-sm text-slate-400">No customer information</p>
              <% end %>
            </div>

            <%!-- Shipping Address --%>
            <div
              :if={@order.shipping_address}
              class="bg-white rounded-2xl border border-slate-200 p-5"
            >
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Shipping Address
              </h2>
              <.address_display address={@order.shipping_address} />
            </div>

            <%!-- Billing Address --%>
            <div :if={@order.billing_address} class="bg-white rounded-2xl border border-slate-200 p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Billing Address
              </h2>
              <.address_display address={@order.billing_address} />
            </div>

            <%!-- Payment Info --%>
            <div :if={@payment} class="bg-white rounded-2xl border border-slate-200 p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Payment
              </h2>
              <div class="space-y-2">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Gateway</span>
                  <span class="font-medium text-slate-800 capitalize">
                    {to_string(@payment.gateway)}
                  </span>
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Status</span>
                  <.payment_status_badge status={@payment.status} />
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Amount</span>
                  <span class="font-mono font-medium text-slate-800">
                    {format_price(@payment.amount, @payment.currency)}
                  </span>
                </div>
                <div
                  :if={@payment.gateway_reference}
                  class="flex items-center justify-between text-sm"
                >
                  <span class="text-slate-500">Reference</span>
                  <span class="font-mono text-xs text-slate-600">
                    {@payment.gateway_reference}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Confirmation Modals --%>
        <.confirm_modal
          id="confirm-order-modal"
          title="Confirm Order"
          message={"Are you sure you want to confirm order #{@order.order_number}? The customer will be notified."}
          confirm_text="Confirm Order"
          confirm_class="bg-blue-600 hover:bg-blue-700 text-white"
          on_confirm="confirm_order"
        />

        <.confirm_modal
          id="processing-order-modal"
          title="Start Processing"
          message={"Begin processing order #{@order.order_number}? This indicates the order is being prepared."}
          confirm_text="Start Processing"
          confirm_class="bg-indigo-600 hover:bg-indigo-700 text-white"
          on_confirm="start_processing"
        />

        <%!-- Mark as Shipped Modal (with tracking number input) --%>
        <.modal id="shipped-order-modal" title="Mark as Shipped" size={:md}>
          <form phx-submit="submit_shipped" class="space-y-4">
            <p class="text-sm text-slate-600">
              Mark order <span class="font-semibold">{@order.order_number}</span> as shipped.
              You can optionally add a tracking number.
            </p>
            <div>
              <label for="tracking-number" class="block text-sm font-medium text-slate-700 mb-1.5">
                Tracking Number (optional)
              </label>
              <input
                type="text"
                id="tracking-number"
                name="tracking_number"
                value={@tracking_number}
                phx-change="update_tracking"
                placeholder="e.g., GH12345678"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                autocomplete="off"
              />
            </div>
            <div class="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                phx-click={hide_modal("shipped-order-modal")}
                class="px-4 py-2.5 text-sm font-medium text-slate-700 bg-white border border-slate-300
                       rounded-xl hover:bg-slate-50 transition-colors"
              >
                Cancel
              </button>
              <button
                type="submit"
                class="px-4 py-2.5 text-sm font-semibold bg-purple-600 text-white
                       rounded-xl hover:bg-purple-700 transition-colors"
              >
                Mark as Shipped
              </button>
            </div>
          </form>
        </.modal>

        <.confirm_modal
          id="delivered-order-modal"
          title="Mark as Delivered"
          message={"Confirm that order #{@order.order_number} has been delivered to the customer?"}
          confirm_text="Mark as Delivered"
          confirm_class="bg-emerald-600 hover:bg-emerald-700 text-white"
          on_confirm="mark_delivered"
        />

        <.confirm_modal
          id="cancel-order-modal"
          title="Cancel Order"
          message={"This action cannot be undone. Cancel order #{@order.order_number}? The customer will be notified."}
          confirm_text="Cancel Order"
          confirm_class="bg-red-600 hover:bg-red-700 text-white"
          on_confirm="cancel_order"
          icon="warning"
          icon_class="text-red-500"
        />
      <% end %>
    </div>
    """
  end

  # ── Components ──

  attr :status, :atom, required: true

  defp order_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
      status_badge_class(@status)
    ]}>
      {status_label(@status)}
    </span>
    """
  end

  attr :status, :atom, required: true

  defp payment_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      payment_badge_class(@status)
    ]}>
      {to_string(@status) |> String.capitalize()}
    </span>
    """
  end

  attr :address, :map, required: true

  defp address_display(assigns) do
    ~H"""
    <div class="text-sm text-slate-700 space-y-0.5">
      <p :if={@address["line_1"]}>{@address["line_1"]}</p>
      <p :if={@address["line_2"]}>{@address["line_2"]}</p>
      <p>
        <span :if={@address["city"]}>{@address["city"]}</span>
        <span :if={@address["region"]}>, {@address["region"]}</span>
      </p>
      <p :if={@address["country"]}>{@address["country"]}</p>
      <p :if={@address["postal_code"]}>{@address["postal_code"]}</p>
    </div>
    """
  end

  # ── Data Loading ──

  defp load_order(socket) do
    %{order_id: id, store_id: store_id} = socket.assigns

    order =
      try do
        case Emakola.Orders.Order
             |> Ash.Query.filter(id: id, store_id: store_id)
             |> Ash.Query.load([:line_items, :customer])
             |> Ash.read(authorize?: false) do
          {:ok, [order]} -> order
          _ -> nil
        end
      rescue
        _ -> nil
      end

    page_title =
      if order,
        do: "Order #{order.order_number}",
        else: "Order Not Found"

    assign(socket, order: order, page_title: page_title)
  end

  defp load_payment(socket) do
    case socket.assigns.order do
      nil ->
        assign(socket, payment: nil)

      order ->
        payment =
          try do
            case Emakola.Payments.Payment
                 |> Ash.Query.filter(order_id: order.id)
                 |> Ash.Query.limit(1)
                 |> Ash.read(authorize?: false) do
              {:ok, [payment]} -> payment
              _ -> nil
            end
          rescue
            _ -> nil
          end

        assign(socket, payment: payment)
    end
  end

  # ── Transition Helper ──

  defp transition_order(socket, action, success_message, opts \\ []) do
    order = socket.assigns.order
    params = Keyword.get(opts, :params, %{})

    case Ash.update(order, params, action: action) do
      {:ok, updated_order} ->
        updated_order = Ash.load!(updated_order, [:line_items, :customer])

        socket =
          socket
          |> assign(order: updated_order)
          |> put_flash(:info, success_message)

        {:noreply, socket}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to update order status")}
    end
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp status_label(:pending), do: "Pending"
  defp status_label(:confirmed), do: "Confirmed"
  defp status_label(:processing), do: "Processing"
  defp status_label(:shipped), do: "Shipped"
  defp status_label(:delivered), do: "Delivered"
  defp status_label(:cancelled), do: "Cancelled"
  defp status_label(_), do: "Unknown"

  defp status_badge_class(:pending), do: "bg-amber-50 text-amber-700"
  defp status_badge_class(:confirmed), do: "bg-blue-50 text-blue-700"
  defp status_badge_class(:processing), do: "bg-indigo-50 text-indigo-700"
  defp status_badge_class(:shipped), do: "bg-purple-50 text-purple-700"
  defp status_badge_class(:delivered), do: "bg-emerald-50 text-emerald-700"
  defp status_badge_class(:cancelled), do: "bg-red-50 text-red-700"
  defp status_badge_class(_), do: "bg-slate-50 text-slate-700"

  defp payment_badge_class(:success), do: "bg-emerald-50 text-emerald-700"
  defp payment_badge_class(:pending), do: "bg-amber-50 text-amber-700"
  defp payment_badge_class(:failed), do: "bg-red-50 text-red-700"
  defp payment_badge_class(:refunded), do: "bg-purple-50 text-purple-700"
  defp payment_badge_class(_), do: "bg-slate-50 text-slate-700"

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y at %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y at %H:%M")
  end

  defp format_datetime(_), do: ""
end
