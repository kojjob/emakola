defmodule EmakolaWeb.Admin.OrderLive.Show do
  @moduledoc """
  Order detail page for the merchant admin dashboard.
  Displays order info, line items, customer details, addresses,
  and modal-based status transition confirmations.

  Design matches the Emakola delivery tracking prototype layout.
  """
  use EmakolaWeb, :live_view

  require Logger

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

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
        protection_hold: nil,
        tracking_number: "",
        tracking_form: to_form(%{"tracking_number" => ""}),
        notes_form: to_form(%{"notes" => ""}),
        fulfillments: [],
        ship_fulfillment_id: nil,
        fulfillment_tracking: "",
        fulfillment_tracking_form: to_form(%{"tracking_number" => ""}),
        delivery_code_fulfillment_id: nil,
        delivery_code: "",
        delivery_code_form: to_form(%{"code" => ""})
      )
      |> load_order()
      |> load_payment()
      |> load_protection_hold()
      |> load_fulfillments()

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
    {:noreply,
     assign(socket,
       tracking_number: tracking,
       tracking_form: to_form(%{"tracking_number" => tracking})
     )}
  end

  @impl true
  def handle_event("submit_shipped", %{"tracking_number" => tracking} = params, socket) do
    transition_order(socket, :mark_shipped, "Order marked as shipped",
      params: %{tracking_number: tracking, courier: courier_from(params["courier"])}
    )
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    order = socket.assigns.order

    case Emakola.Orders.update_order_notes(order, %{notes: notes}, authorize?: false) do
      {:ok, updated_order} ->
        socket =
          socket
          |> assign(
            order: updated_order,
            notes_form: to_form(%{"notes" => updated_order.notes || ""})
          )
          |> put_flash(:info, "Notes updated")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update notes")}
    end
  end

  @impl true
  def handle_event("send_supplier_fulfillment", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.fulfillments, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      fulfillment ->
        case Emakola.Notifications.Dispatcher.dispatch_supplier_fulfillment(fulfillment.id) do
          {:ok, _job} ->
            {:noreply,
             socket
             |> load_fulfillments()
             |> put_flash(:info, "Sent to supplier")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not send to supplier")}
        end
    end
  end

  @impl true
  def handle_event("select_ship_fulfillment", %{"id" => id}, socket) do
    {:noreply,
     assign(socket,
       ship_fulfillment_id: id,
       fulfillment_tracking: "",
       fulfillment_tracking_form: to_form(%{"tracking_number" => ""})
     )}
  end

  @impl true
  def handle_event("update_fulfillment_tracking", %{"tracking_number" => tracking}, socket) do
    {:noreply,
     assign(socket,
       fulfillment_tracking: tracking,
       fulfillment_tracking_form: to_form(%{"tracking_number" => tracking})
     )}
  end

  @impl true
  def handle_event("submit_ship_fulfillment", %{"tracking_number" => tracking}, socket) do
    transition_fulfillment(
      socket,
      socket.assigns.ship_fulfillment_id,
      :mark_shipped,
      "Fulfillment marked shipped",
      params: %{tracking_number: tracking}
    )
  end

  # -- Proof of delivery ------------------------------------------------------
  #
  # Marking an order delivered is a merchant asserting something about
  # themselves. The OTP is the only path in the system that requires the buyer
  # to assent, so it is the one that actually reduces delivery fraud.

  @impl true
  def handle_event("request_delivery_code", %{"id" => id}, socket) do
    case Emakola.Orders.CustomerDelivery.request_delivery_code(socket.assigns.store_id, id) do
      {:ok, proof} ->
        {:noreply,
         socket
         |> assign(delivery_code_fulfillment_id: id, delivery_code: "")
         |> load_fulfillments()
         |> put_flash(:info, "Delivery code sent to #{proof.sent_to}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, delivery_code_error(reason))}
    end
  end

  @impl true
  def handle_event("enter_delivery_code", %{"id" => id}, socket) do
    {:noreply, assign(socket, delivery_code_fulfillment_id: id, delivery_code: "")}
  end

  @impl true
  def handle_event("cancel_delivery_code", _params, socket) do
    {:noreply, assign(socket, delivery_code_fulfillment_id: nil, delivery_code: "")}
  end

  @impl true
  def handle_event("submit_delivery_code", %{"fulfillment_id" => id, "code" => code}, socket) do
    # store_id is read from assigns at handle-event time, never from the form.
    case Emakola.Orders.CustomerDelivery.verify_delivery(socket.assigns.store_id, id, code) do
      {:ok, _fulfillment} ->
        {:noreply,
         socket
         |> assign(delivery_code_fulfillment_id: nil, delivery_code: "")
         |> load_order()
         |> load_fulfillments()
         |> put_flash(:info, "Customer confirmed delivery")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, delivery_code_error(reason))}
    end
  end

  @impl true
  def handle_event("deliver_fulfillment", %{"id" => id}, socket) do
    transition_fulfillment(socket, id, :mark_delivered, "Fulfillment marked delivered")
  end

  @impl true
  def handle_event("cancel_fulfillment", %{"id" => id}, socket) do
    transition_fulfillment(socket, id, :cancel, "Fulfillment cancelled")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%!-- Back link & Header --%>
      <div class="flex items-center gap-4">
        <.link
          navigate={~p"/admin/orders"}
          class="p-2 rounded-control hover:bg-slate-100 transition-colors"
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
            <.status_badge :if={@order} status={@order.status} variant={:order} />
          </div>
          <p :if={@order} class="text-sm text-slate-500 mt-0.5">
            Placed {format_datetime(@order.inserted_at)}
          </p>
        </div>
      </div>

      <%= if @order do %>
        <%!-- Order journey — where this order stands, readable by shape and
              colour alone. Cancelled/refunded orders end on their own node. --%>
        <.admin_card padding={:none} class="p-5" id="order-timeline">
          <div class="flex items-center overflow-x-auto">
            <%= for {step, idx} <- Enum.with_index(journey_steps(@order.status)) do %>
              <div
                :if={idx > 0}
                class={[
                  "flex-1 h-0.5 min-w-6",
                  if(step.state in [:done, :current, :ended],
                    do: "bg-emerald-500",
                    else: "bg-slate-200"
                  )
                ]}
              />
              <div
                class="flex flex-col items-center gap-1.5 px-2"
                data-step={step.step}
                data-state={step.state}
              >
                <div class={[
                  "w-9 h-9 rounded-full flex items-center justify-center",
                  journey_node_class(step.state)
                ]}>
                  <.icon name={step.icon} class="size-4" />
                </div>
                <span class={[
                  "text-[11px] font-semibold whitespace-nowrap",
                  if(step.state == :todo, do: "text-slate-400", else: "text-slate-700")
                ]}>
                  {step.label}
                </span>
              </div>
            <% end %>
          </div>
        </.admin_card>

        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Main Column --%>
          <div class="lg:col-span-2 space-y-6">
            <%!-- Status Actions --%>
            <.admin_card padding={:none} class="p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Order Actions
              </h2>
              <div class="flex flex-wrap gap-3">
                <.admin_button
                  :if={@order.status == :pending}
                  phx-click={show_modal("confirm-order-modal")}
                >
                  Confirm Order
                </.admin_button>
                <button
                  :if={@order.status == :confirmed}
                  phx-click={show_modal("processing-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-control text-sm font-semibold
                         bg-indigo-600 text-white hover:bg-indigo-700 transition-colors"
                >
                  Start Processing
                </button>
                <button
                  :if={@order.status == :processing}
                  phx-click={show_modal("shipped-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 rounded-control text-sm font-semibold
                         bg-purple-600 text-white hover:bg-purple-700 transition-colors"
                >
                  Mark as Shipped
                </button>
                <.admin_button
                  :if={@order.status == :shipped}
                  phx-click={show_modal("delivered-order-modal")}
                >
                  Mark as Delivered
                </.admin_button>
                <button
                  :if={@order.status not in [:cancelled, :delivered]}
                  phx-click={show_modal("cancel-order-modal")}
                  class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-red-200
                         rounded-control text-sm font-medium text-red-600 hover:bg-red-50 transition-colors"
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
            </.admin_card>

            <%!-- Line Items --%>
            <.admin_card padding={:none} class="overflow-hidden">
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
                        <td class="px-5 py-3">
                          <div class="flex items-center gap-3">
                            <.product_thumb
                              url={line_item_image_url(item)}
                              alt={item.product_title}
                              class="w-9 h-9"
                            />
                            <span class="text-slate-800 font-medium">{item.product_title}</span>
                          </div>
                        </td>
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
                <div
                  :if={@order.margin}
                  id="order-margin"
                  class="flex items-center justify-between text-sm pt-2 border-t border-slate-100"
                >
                  <span class="text-slate-500">Margin</span>
                  <span class="font-mono font-medium text-success">
                    {format_price(@order.margin, @order.currency)}
                  </span>
                </div>
              </div>
            </.admin_card>

            <%!-- Fulfillments --%>
            <.admin_card :if={@fulfillments != []} padding={:none} class="overflow-hidden">
              <div class="px-5 py-4 border-b border-slate-100">
                <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide">
                  Fulfillments
                </h2>
              </div>
              <div class="divide-y divide-slate-100">
                <div :for={f <- @fulfillments} class="p-5 space-y-3">
                  <div class="flex items-center justify-between gap-3">
                    <div class="flex items-center gap-2">
                      <h3 class="text-sm font-semibold text-slate-900">
                        {fulfillment_label(f)}
                      </h3>
                      <.fulfillment_status_badge status={f.status} />
                    </div>
                    <span
                      :if={f.supplier_id}
                      class="inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-violet-50 text-violet-700"
                    >
                      Supplier
                    </span>
                  </div>

                  <div :if={f.supplier_id} class="text-xs text-slate-500 space-y-0.5">
                    <p :if={f.notified_at}>
                      Notified {format_datetime(f.notified_at)}
                      <span :if={f.notified_via}>via {to_string(f.notified_via)}</span>
                    </p>
                    <p :if={f.tracking_number}>
                      Tracking: <span class="font-mono">{f.tracking_number}</span>
                    </p>
                  </div>

                  <ul class="text-sm text-slate-600 space-y-1">
                    <li :for={item <- f.line_items} class="flex items-center justify-between">
                      <span>{item.product_title}</span>
                      <span class="text-slate-400">× {item.quantity}</span>
                    </li>
                  </ul>

                  <div
                    :if={f.status not in [:delivered, :cancelled]}
                    class="flex flex-wrap gap-2 pt-1"
                  >
                    <.admin_button
                      :if={not is_nil(f.supplier_id) and f.status in [:pending, :notified]}
                      size={:sm}
                      phx-click="send_supplier_fulfillment"
                      phx-value-id={f.id}
                    >
                      {if f.status == :notified, do: "Resend", else: "Send to supplier"}
                    </.admin_button>
                    <button
                      :if={f.status in [:pending, :notified]}
                      phx-click={
                        JS.push("select_ship_fulfillment", value: %{id: f.id})
                        |> show_modal("ship-fulfillment-modal")
                      }
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-semibold transition-colors"
                    >
                      Mark shipped
                    </button>
                    <%!-- Proof of delivery. "Mark delivered" is the merchant
                          attesting to their own performance; the code is the
                          only path the buyer has to assent, so it leads. --%>
                    <.admin_button
                      :if={f.status == :shipped}
                      size={:sm}
                      phx-click="request_delivery_code"
                      phx-value-id={f.id}
                    >
                      {if delivery_proof?(f), do: "Send new code", else: "Send delivery code"}
                    </.admin_button>
                    <button
                      :if={f.status == :shipped && delivery_proof?(f)}
                      phx-click="enter_delivery_code"
                      phx-value-id={f.id}
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 hover:bg-slate-50 text-slate-700 rounded-lg text-xs font-semibold transition-colors"
                    >
                      Enter customer code
                    </button>
                    <button
                      :if={f.status == :shipped}
                      phx-click="deliver_fulfillment"
                      phx-value-id={f.id}
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 border border-slate-200 hover:bg-slate-50 text-slate-500 rounded-lg text-xs font-medium transition-colors"
                    >
                      Mark delivered without code
                    </button>
                    <button
                      phx-click="cancel_fulfillment"
                      phx-value-id={f.id}
                      data-confirm="Cancel this fulfillment?"
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white border border-red-200 text-red-600 hover:bg-red-50 rounded-lg text-xs font-medium transition-colors"
                    >
                      Cancel
                    </button>
                  </div>

                  <%!-- The buyer reads this code out at the door. It is never
                        shown to the merchant when issued — only the masked
                        recipient is — so entering it proves someone at the
                        delivery address has it. --%>
                  <.form
                    :if={@delivery_code_fulfillment_id == f.id}
                    for={@delivery_code_form}
                    id={"delivery-code-form-#{f.id}"}
                    phx-submit="submit_delivery_code"
                    class="mt-3 flex flex-col gap-2 rounded-lg border border-slate-200 bg-slate-50 p-3 sm:flex-row sm:items-center"
                  >
                    <input type="hidden" name="fulfillment_id" value={f.id} />
                    <label for={"delivery-code-#{f.id}"} class="sr-only">
                      Delivery code from the customer
                    </label>
                    <.input
                      field={@delivery_code_form[:code]}
                      type="text"
                      id={"delivery-code-#{f.id}"}
                      inputmode="numeric"
                      autocomplete="off"
                      placeholder="6-digit code"
                      class="flex-1 px-3 py-2 text-sm font-mono rounded-lg border border-slate-200 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
                    />
                    <div class="flex gap-2">
                      <.admin_button type="submit" size={:sm}>Confirm delivery</.admin_button>
                      <button
                        type="button"
                        phx-click="cancel_delivery_code"
                        class="px-3 py-1.5 text-xs font-medium text-slate-500 hover:text-slate-700"
                      >
                        Cancel
                      </button>
                    </div>
                  </.form>
                </div>
              </div>
            </.admin_card>

            <%!-- Notes --%>
            <.admin_card padding={:none} class="p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-3">
                Notes
              </h2>
              <.form for={@notes_form} id="order-notes-form" phx-submit="update_notes">
                <.input
                  field={@notes_form[:notes]}
                  id="order-notes"
                  type="textarea"
                  rows="3"
                  placeholder="Add internal notes about this order..."
                  class="w-full px-3 py-2 text-sm border border-slate-200 rounded-control
                         focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                         focus:border-emerald-500 placeholder:text-slate-400 resize-none"
                />
                <div class="flex justify-end mt-2">
                  <.admin_button type="submit">
                    Save Notes
                  </.admin_button>
                </div>
              </.form>
            </.admin_card>
          </div>

          <%!-- Sidebar --%>
          <div class="space-y-6">
            <%!-- Customer Info --%>
            <.admin_card padding={:none} class="p-5">
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
            </.admin_card>

            <%!-- Shipping Address --%>
            <.admin_card
              :if={@order.shipping_address}
              id="shipping-address-card"
              padding={:none}
              class="p-5"
            >
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Shipping Address
              </h2>
              <.address_display address={@order.shipping_address} />
            </.admin_card>

            <%!-- Billing Address --%>
            <.admin_card
              :if={@order.billing_address}
              id="billing-address-card"
              padding={:none}
              class="p-5"
            >
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Billing Address
              </h2>
              <.address_display address={@order.billing_address} />
            </.admin_card>

            <%!-- Payment Info --%>
            <.admin_card :if={@payment} padding={:none} class="p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Payment
              </h2>
              <div class="space-y-2">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Paid with</span>
                  <.payment_rail_chip id="payment-rail-chip" rail={payment_rail(@payment)} />
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Status</span>
                  <.status_badge status={@payment.status} variant={:payment} />
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
            </.admin_card>

            <%!-- Buyer Protection (TC-2) --%>
            <.admin_card :if={@protection_hold} padding={:none} class="p-5">
              <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-4">
                Buyer Protection
              </h2>
              <div class="space-y-2">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Status</span>
                  <.protection_hold_status_badge status={hold_display_status(@protection_hold)} />
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Amount</span>
                  <span class="font-mono font-medium text-slate-800">
                    {format_price(@protection_hold.amount, @order.currency)}
                  </span>
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Fee</span>
                  <span class="font-mono text-slate-600">
                    {format_price(@protection_hold.fee, @order.currency)}
                  </span>
                </div>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-slate-500">Net</span>
                  <span class="font-mono font-medium text-slate-800">
                    {format_price(@protection_hold.net, @order.currency)}
                  </span>
                </div>
                <div
                  :if={@protection_hold.release_after}
                  class="flex items-center justify-between text-sm"
                >
                  <span class="text-slate-500">Release ETA</span>
                  <span class="text-slate-700">
                    {format_datetime(@protection_hold.release_after)}
                  </span>
                </div>
                <div
                  :if={@protection_hold.release_reason}
                  class="flex items-center justify-between text-sm"
                >
                  <span class="text-slate-500">Release reason</span>
                  <span class="text-slate-700">{humanise(@protection_hold.release_reason)}</span>
                </div>
              </div>
            </.admin_card>
          </div>
        </div>

        <%!-- Confirmation Modals --%>
        <.confirm_modal
          id="confirm-order-modal"
          title="Confirm Order"
          message={"Are you sure you want to confirm order #{@order.order_number}? The customer will be notified."}
          confirm_text="Confirm Order"
          confirm_class="bg-primary hover:bg-primary-hover text-white"
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
          <.form
            for={@tracking_form}
            id="shipped-order-form"
            phx-submit="submit_shipped"
            class="space-y-4"
          >
            <p class="text-sm text-slate-600">
              Mark order <span class="font-semibold">{@order.order_number}</span> as shipped.
              You can optionally add a tracking number.
            </p>
            <div>
              <label for="tracking-number" class="block text-sm font-medium text-slate-700 mb-1.5">
                Tracking Number (optional)
              </label>
              <.input
                field={@tracking_form[:tracking_number]}
                type="text"
                id="tracking-number"
                phx-change="update_tracking"
                placeholder="e.g., GH12345678"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                autocomplete="off"
              />
            </div>
            <%!-- Which courier the reference belongs to, so the buyer gets a
                  link instead of a number they must guess where to type.
                  Couriers with no verified public tracking URL are still
                  selectable — the number then renders as plain text rather
                  than a link to a guessed destination. --%>
            <div>
              <label for="order-courier" class="block text-sm font-medium text-slate-700 mb-1.5">
                Courier (optional)
              </label>
              <select
                id="order-courier"
                name="courier"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
              >
                <option value="">Not specified</option>
                <option :for={c <- Emakola.Shipping.Couriers.list()} value={to_string(c.id)}>
                  {c.label}
                </option>
              </select>
            </div>
            <div class="flex items-center justify-end gap-3 pt-2">
              <.admin_button variant={:secondary} phx-click={hide_modal("shipped-order-modal")}>
                Cancel
              </.admin_button>
              <button
                type="submit"
                class="px-4 py-2.5 text-sm font-semibold bg-purple-600 text-white
                       rounded-control hover:bg-purple-700 transition-colors"
              >
                Mark as Shipped
              </button>
            </div>
          </.form>
        </.modal>

        <.confirm_modal
          id="delivered-order-modal"
          title="Mark as Delivered"
          message={"Confirm that order #{@order.order_number} has been delivered to the customer?"}
          confirm_text="Mark as Delivered"
          confirm_class="bg-primary hover:bg-primary-hover text-white"
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

        <%!-- Mark fulfillment shipped modal --%>
        <.modal id="ship-fulfillment-modal" title="Mark Fulfillment Shipped" size={:md}>
          <.form
            for={@fulfillment_tracking_form}
            id="ship-fulfillment-form"
            phx-submit="submit_ship_fulfillment"
            class="space-y-4"
          >
            <p class="text-sm text-slate-600">
              Add an optional tracking number for this fulfillment.
            </p>
            <div>
              <label
                for="fulfillment-tracking-number"
                class="block text-sm font-medium text-slate-700 mb-1.5"
              >
                Tracking Number (optional)
              </label>
              <.input
                field={@fulfillment_tracking_form[:tracking_number]}
                type="text"
                id="fulfillment-tracking-number"
                phx-change="update_fulfillment_tracking"
                placeholder="e.g., GH12345678"
                class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300
                       focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                autocomplete="off"
              />
            </div>
            <div class="flex items-center justify-end gap-3 pt-2">
              <.admin_button variant={:secondary} phx-click={hide_modal("ship-fulfillment-modal")}>
                Cancel
              </.admin_button>
              <button
                type="submit"
                phx-click={hide_modal("ship-fulfillment-modal")}
                class="px-4 py-2.5 text-sm font-semibold bg-purple-600 text-white
                       rounded-control hover:bg-purple-700 transition-colors"
              >
                Mark Shipped
              </button>
            </div>
          </.form>
        </.modal>
      <% end %>
    </div>
    """
  end

  # ── Components ──

  attr :status, :atom, required: true

  defp fulfillment_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium",
      fulfillment_badge_class(@status)
    ]}>
      {to_string(@status) |> String.capitalize()}
    </span>
    """
  end

  attr :status, :atom, required: true

  defp protection_hold_status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium capitalize",
      protection_hold_badge_class(@status)
    ]}>
      {to_string(@status) |> String.capitalize()}
    </span>
    """
  end

  attr :address, :map, required: true

  defp address_display(assigns) do
    assigns =
      assigns
      |> assign(:name, address_name(assigns.address))
      |> assign(:line_1, address_line_1(assigns.address))
      |> assign(:line_2, address_value(assigns.address, ["line_2", :line_2, "line2", :line2]))
      |> assign(:city, address_value(assigns.address, ["city", :city]))
      |> assign(:region, address_value(assigns.address, ["region", :region]))
      |> assign(:country, address_value(assigns.address, ["country", :country]))
      |> assign(:postal_code, address_value(assigns.address, ["postal_code", :postal_code]))
      |> assign(
        :digital_address,
        address_value(assigns.address, ["digital_address", :digital_address])
      )
      |> assign(:landmark, address_value(assigns.address, ["landmark", :landmark]))
      |> assign(:phone, address_value(assigns.address, ["phone", :phone]))

    ~H"""
    <div class="text-sm text-slate-700 space-y-0.5">
      <p :if={@name} class="font-semibold text-slate-900">{@name}</p>
      <p :if={@line_1}>{@line_1}</p>
      <p :if={@line_2}>{@line_2}</p>
      <p>
        <span :if={@city}>{@city}</span>
        <span :if={@region}>, {@region}</span>
      </p>
      <p :if={@country}>{@country}</p>
      <p :if={@postal_code}>{@postal_code}</p>
      <div :if={@digital_address} class="flex items-center gap-2 pt-1">
        <span class="font-mono text-xs font-medium text-slate-700 bg-slate-100 rounded px-1.5 py-0.5">
          {@digital_address}
        </span>
        <button
          type="button"
          phx-click={JS.dispatch("copy-to-clipboard", detail: %{text: @digital_address})}
          class="text-xs font-medium text-slate-500 hover:text-slate-700 transition-colors cursor-pointer"
        >
          Copy
        </button>
      </div>
      <p :if={@landmark} class="text-xs text-slate-500">Near {@landmark}</p>
      <p :if={@phone} class="pt-1 text-xs text-slate-500">{@phone}</p>
    </div>
    """
  end

  # ── Order journey ──

  @journey [
    {:pending, "Placed", "hero-shopping-bag"},
    {:confirmed, "Confirmed", "hero-check-circle"},
    {:processing, "Processing", "hero-cog-6-tooth"},
    {:shipped, "Shipped", "hero-truck"},
    {:delivered, "Delivered", "hero-home"}
  ]

  defp journey_steps(:cancelled) do
    [
      %{step: :pending, label: "Placed", icon: "hero-shopping-bag", state: :done},
      %{step: :cancelled, label: "Cancelled", icon: "hero-x-circle", state: :ended}
    ]
  end

  defp journey_steps(:refunded) do
    [
      %{step: :pending, label: "Placed", icon: "hero-shopping-bag", state: :done},
      %{step: :refunded, label: "Refunded", icon: "hero-banknotes", state: :ended}
    ]
  end

  defp journey_steps(status) do
    current = Enum.find_index(@journey, fn {step, _, _} -> step == status end) || 0

    @journey
    |> Enum.with_index()
    |> Enum.map(fn {{step, label, icon}, idx} ->
      state =
        cond do
          idx < current -> :done
          idx == current -> :current
          true -> :todo
        end

      %{step: step, label: label, icon: icon, state: state}
    end)
  end

  defp journey_node_class(:done), do: "bg-emerald-500 text-white"
  defp journey_node_class(:current), do: "bg-primary text-white ring-4 ring-emerald-100"
  defp journey_node_class(:todo), do: "bg-slate-100 text-slate-400"

  defp journey_node_class(:ended),
    do: "bg-red-500 text-white ring-4 ring-red-100"

  # ── Payment rail ──

  # The rail is read from the gateway's stored charge data: Paystack keeps
  # channel + authorization.bank ("MTN", "Telecel", "AirtelTigo"); Hubtel's
  # webhook stores neither, so its payments fall back to the gateway chip.
  defp payment_rail(payment) do
    gateway_response = payment.gateway_response || %{}

    channel =
      gateway_response["channel"] || get_in(gateway_response, ["authorization", "channel"])

    cond do
      channel == "card" -> :card
      channel == "mobile_money" -> momo_rail(get_in(gateway_response, ["authorization", "bank"]))
      true -> payment.gateway
    end
  end

  defp momo_rail(bank) do
    bank = String.downcase(to_string(bank))

    cond do
      bank =~ "mtn" -> :mtn_momo
      bank =~ "telecel" or bank =~ "vodafone" -> :telecel_cash
      bank =~ "airtel" or bank =~ "tigo" -> :airteltigo
      true -> :mobile_money
    end
  end

  # ── Line item image ──

  defp line_item_image_url(item) do
    case item.variant do
      %{product: %{images: [image | _]}} -> image.thumbnail_url || image.url
      _ -> nil
    end
  end

  # ── Data Loading ──

  # Matched against the known list rather than converted: String.to_atom/1 on
  # user input is atom-table exhaustion, and to_existing_atom/1 raises on
  # unknown input, which is a 500.
  defp courier_from(value) do
    Enum.find(Emakola.Shipping.Couriers.ids(), &(to_string(&1) == value))
  end

  defp delivery_code_error(:rate_limited),
    do: "Too many codes sent for this delivery. Try again in a few minutes."

  defp delivery_code_error(:fulfillment_not_shipped),
    do: "Mark it shipped before sending a delivery code."

  defp delivery_code_error(:customer_phone_missing),
    do: "This order has no phone number to send the code to."

  defp delivery_code_error(:delivery_code_not_requested), do: "Send the customer a code first."

  defp delivery_code_error(:invalid_code),
    do: "That code does not match. Check with the customer."

  defp delivery_code_error(:expired), do: "That code expired. Send a new one."
  defp delivery_code_error(:already_verified), do: "This delivery is already confirmed."

  defp delivery_code_error(:too_many_attempts),
    do: "Too many wrong attempts. Send a new code."

  defp delivery_code_error(:delivery_failed), do: "Could not send the code. Try again."
  defp delivery_code_error(_reason), do: "Could not complete that. Try again."

  defp load_order(socket) do
    %{order_id: id, store_id: store_id} = socket.assigns

    order =
      try do
        case Emakola.Orders.get_order_for_admin(id, store_id, authorize?: false) do
          {:ok, nil} ->
            nil

          {:ok, order} ->
            Ash.load!(
              order,
              [:customer, :margin, line_items: [variant: [product: [:images]]]],
              authorize?: false
            )

          _ ->
            nil
        end
      rescue
        exception ->
          Logger.error(
            "[order_live.show] load_order loading order raised: #{Exception.message(exception)}"
          )

          nil
      end

    page_title =
      if order,
        do: "Order #{order.order_number}",
        else: "Order Not Found"

    assign(socket,
      order: order,
      page_title: page_title,
      notes_form: to_form(%{"notes" => (order && order.notes) || ""})
    )
  end

  defp load_payment(socket) do
    case socket.assigns.order do
      nil ->
        assign(socket, payment: nil)

      order ->
        payment =
          try do
            case Emakola.Payments.get_payment_by_order(order.id, authorize?: false) do
              {:ok, payment} -> payment
              _ -> nil
            end
          rescue
            exception ->
              Logger.error(
                "[order_live.show] load_payment loading payment raised: #{Exception.message(exception)}"
              )

              nil
          end

        assign(socket, payment: payment)
    end
  end

  defp load_protection_hold(socket) do
    case socket.assigns.order do
      nil ->
        assign(socket, protection_hold: nil)

      order ->
        hold =
          try do
            Emakola.Payments.ProtectionHolds.get_hold_for_order(
              order.id,
              socket.assigns.store_id
            )
          rescue
            exception ->
              Logger.error(
                "[order_live.show] load_protection_hold raised: #{Exception.message(exception)}"
              )

              nil
          end

        assign(socket, protection_hold: hold)
    end
  end

  # %Ash.NotLoaded{} is truthy — guarding on the association directly would
  # claim a code had already been sent whenever the load was forgotten.
  defp delivery_proof?(%{delivery_proof: %Emakola.Orders.FulfillmentDeliveryProof{}}), do: true
  defp delivery_proof?(_fulfillment), do: false

  defp load_fulfillments(socket) do
    case socket.assigns.order do
      nil ->
        assign(socket, fulfillments: [])

      order ->
        fulfillments =
          try do
            order.id
            |> Emakola.Orders.list_fulfillments_by_order!(authorize?: false)
            |> Ash.load!(:delivery_proof, authorize?: false)
          rescue
            exception ->
              Logger.error(
                "[order_live.show] load_fulfillments loading fulfillments raised: #{Exception.message(exception)}"
              )

              []
          end

        assign(socket, fulfillments: fulfillments)
    end
  end

  # ── Fulfillment Transition Helper ──

  defp transition_fulfillment(socket, id, action, message, opts \\ []) do
    params = Keyword.get(opts, :params, %{})
    fulfillment = Enum.find(socket.assigns.fulfillments, &(&1.id == id))

    if fulfillment do
      result =
        case action do
          :mark_shipped ->
            Emakola.Orders.mark_fulfillment_shipped(fulfillment, params, authorize?: false)

          :mark_delivered ->
            Emakola.Orders.mark_fulfillment_delivered(fulfillment, authorize?: false)

          :cancel ->
            Emakola.Orders.cancel_fulfillment(fulfillment, authorize?: false)
        end

      case result do
        {:ok, _updated} ->
          {:noreply,
           socket
           |> assign(ship_fulfillment_id: nil, fulfillment_tracking: "")
           |> load_fulfillments()
           |> put_flash(:info, message)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update fulfillment")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Transition Helper ──

  defp transition_order(socket, action, success_message, opts \\ []) do
    order = socket.assigns.order
    params = Keyword.get(opts, :params, %{})

    result =
      case action do
        :confirm -> Emakola.Orders.confirm_order(order, authorize?: false)
        :start_processing -> Emakola.Orders.start_processing_order(order, authorize?: false)
        :mark_shipped -> Emakola.Orders.mark_order_shipped(order, params, authorize?: false)
        :mark_delivered -> Emakola.Orders.mark_order_delivered(order, authorize?: false)
        :cancel -> Emakola.Orders.cancel_order(order, authorize?: false)
      end

    case result do
      {:ok, updated_order} ->
        updated_order =
          Ash.load!(updated_order, [:line_items, :customer, :margin], authorize?: false)

        socket =
          socket
          |> assign(order: updated_order)
          |> put_flash(:info, success_message)

        {:noreply, socket}

      {:error, _error} ->
        # The most likely cause is a stale page: the row moved on (another tab,
        # a back button) so the guarded UPDATE matched nothing. Re-read it so
        # the page stops showing a status that is no longer true — otherwise
        # the merchant just clicks the same dead button again.
        {:noreply,
         socket
         |> reload_order()
         |> put_flash(
           :error,
           "Couldn't update this order — it may have changed elsewhere. Refreshed to the latest status."
         )}
    end
  end

  defp reload_order(socket) do
    case Ash.get(Emakola.Orders.Order, socket.assigns.order.id, authorize?: false) do
      {:ok, fresh} ->
        assign(socket,
          order: Ash.load!(fresh, [:line_items, :customer, :margin], authorize?: false)
        )

      _ ->
        socket
    end
  end

  # ── Helpers ──

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp fulfillment_badge_class(:pending), do: "bg-warning-soft text-warning"
  defp fulfillment_badge_class(:notified), do: "bg-info-soft text-info"
  defp fulfillment_badge_class(:shipped), do: "bg-purple-50 text-purple-700"
  defp fulfillment_badge_class(:delivered), do: "bg-success-soft text-success"
  defp fulfillment_badge_class(:cancelled), do: "bg-danger-soft text-danger"
  defp fulfillment_badge_class(_), do: "bg-slate-50 text-slate-700"

  # A complaint freezes the auto-release timer without changing the hold's
  # underlying `status` (still `:held`) — see `ProtectionHold`'s moduledoc.
  # The admin pill shows "Frozen" instead so staff notice the open complaint
  # without a separate indicator.
  defp hold_display_status(%{status: :held, frozen_at: nil}), do: :held
  defp hold_display_status(%{status: :held}), do: :frozen
  defp hold_display_status(%{status: status}), do: status

  defp protection_hold_badge_class(:held), do: "bg-warning-soft text-warning"
  defp protection_hold_badge_class(:frozen), do: "bg-danger-soft text-danger"
  defp protection_hold_badge_class(:released), do: "bg-success-soft text-success"
  defp protection_hold_badge_class(:refunded), do: "bg-slate-100 text-slate-600"
  defp protection_hold_badge_class(_), do: "bg-slate-50 text-slate-700"

  defp humanise(value) when is_atom(value) do
    value |> to_string() |> String.replace("_", " ") |> String.capitalize()
  end

  defp fulfillment_label(%{supplier: %{name: name}}) when is_binary(name), do: name
  defp fulfillment_label(_), do: "Your stock"

  defp address_name(address) do
    address_value(address, ["name", :name]) ||
      [
        address_value(address, ["first_name", :first_name]),
        address_value(address, ["last_name", :last_name])
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")
      |> blank_to_nil()
  end

  defp address_line_1(address) do
    address_value(address, [
      "line_1",
      :line_1,
      "line1",
      :line1,
      "address_line_1",
      :address_line_1,
      "address",
      :address
    ])
  end

  defp address_value(address, keys) when is_map(address) do
    Enum.find_value(keys, fn key ->
      address
      |> Map.get(key)
      |> normalize_address_value()
    end)
  end

  defp normalize_address_value(value) when is_binary(value), do: blank_to_nil(value)
  defp normalize_address_value(nil), do: nil
  defp normalize_address_value(value), do: value |> to_string() |> blank_to_nil()

  defp blank_to_nil(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y at %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%d %b %Y at %H:%M")
  end

  defp format_datetime(_), do: ""
end
