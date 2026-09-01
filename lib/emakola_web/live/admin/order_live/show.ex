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
  import EmakolaWeb.QRComponents, only: [qr_panel: 1]

  alias EmakolaWeb.QR

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

    # The SLA sweeper escalates in the background, so this page can go stale
    # while a merchant is looking straight at it. Only dashboard_live subscribed
    # to this topic before.
    if connected?(socket) and store_id do
      Phoenix.PubSub.subscribe(Emakola.PubSub, "store:#{store_id}:orders")
    end

    {:ok, socket}
  end

  @impl true
  def handle_info({:order_event, _event, %{id: order_id}}, socket) do
    if order_id == socket.assigns.order_id do
      {:noreply, socket |> load_order() |> load_fulfillments()}
    else
      {:noreply, socket}
    end
  end

  def handle_info(_message, socket), do: {:noreply, socket}

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
  # Revocation for a link the merchant sent to the wrong chat. Bumping the
  # version invalidates every token already minted for this fulfilment.
  def handle_event("rotate_supplier_link", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.fulfillments, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      fulfillment ->
        case Emakola.Orders.rotate_fulfillment_supplier_link(fulfillment, authorize?: false) do
          {:ok, _rotated} ->
            {:noreply,
             socket
             |> load_fulfillments()
             |> put_flash(:info, "New link made. The old one stopped working.")}

          {:error, reason} ->
            Logger.error("[order_live.show] rotate_supplier_link failed: #{inspect(reason)}")
            {:noreply, put_flash(socket, :error, "Could not make a new link")}
        end
    end
  end

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
  # The merchant vouching for their own delivery. Its own action, and it records
  # who pressed it: this is the one route to :delivered with no counterparty,
  # and it still starts the payout clock.
  def handle_event("deliver_fulfillment", %{"id" => id}, socket) do
    transition_fulfillment(socket, id, :self_attest_delivered, "Marked delivered without proof",
      params: %{delivery_attested_by_id: attesting_merchant_id(socket)}
    )
  end

  @impl true
  # Cancelling a supplier group the supplier never shipped must also close out
  # what the merchant nominally owes for it, or they are left with a debt for
  # goods that never moved.
  def handle_event("cancel_fulfillment", %{"id" => id}, socket) do
    result = transition_fulfillment(socket, id, :cancel, "Fulfillment cancelled")
    void_unfulfilled_debt(id)
    result
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

              <%!-- Every button above is guarded on a status, so a delivered or
                    cancelled order emptied this card and left a heading over
                    blank space — which reads as a page that failed to load
                    rather than as "nothing to do". Naming the end state keeps
                    the card's shape constant across an order's life, which
                    matters for merchants who navigate by shape rather than by
                    reading labels. --%>
              <p
                :if={@order.status in [:delivered, :cancelled]}
                id="order-actions-none"
                class="flex items-center gap-2 text-sm text-slate-500"
              >
                <.icon
                  name={
                    if @order.status == :delivered,
                      do: "hero-check-circle",
                      else: "hero-x-circle"
                  }
                  class={[
                    "size-5 shrink-0",
                    if(@order.status == :delivered, do: "text-success", else: "text-slate-400")
                  ]}
                />
                {if @order.status == :delivered,
                  do: "This order is done.",
                  else: "This order was cancelled."}
              </p>
            </.admin_card>

            <%!-- Packing slip. It goes in the parcel, so it sits with the work
                  rather than above it — the order journey and the next action
                  are what a merchant opens this page for. In Phase 2 this same
                  square is what gets scanned at handoff to land back here. --%>
            <.admin_card :if={@current_store} id="packing-slip" class="print-sheet">
              <.qr_panel
                id="order-qr"
                svg={QR.order_tracking_svg(@current_store, @order)}
                eyebrow={@current_store.name}
                title={@order.order_number}
                hint="Put this in the parcel. Buyers scan to track."
                caption="Scan to track this order"
                url={QR.order_tracking_url(@current_store, @order)}
              >
                <:actions>
                  <.admin_button
                    id="packing-slip-print"
                    size={:sm}
                    phx-click={JS.dispatch("makola:print")}
                  >
                    Print slip
                  </.admin_button>
                </:actions>
              </.qr_panel>
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
                    <p
                      :if={f.accepted_at}
                      class="flex items-center gap-1.5 font-semibold text-success"
                    >
                      <.icon name="hero-check-circle" class="size-4 shrink-0" />
                      Supplier has it · {format_datetime(f.accepted_at)}
                    </p>
                    <p
                      :if={f.declined_at}
                      class="flex items-center gap-1.5 font-semibold text-danger"
                    >
                      <.icon name="hero-x-circle" class="size-4 shrink-0" />
                      No stock · find another supplier
                    </p>
                    <p :if={f.tracking_number}>
                      Tracking: <span class="font-mono">{f.tracking_number}</span>
                    </p>
                    <p
                      :if={f.escalation_level >= 3 and f.status in [:pending, :notified]}
                      class="flex items-center gap-1.5 font-semibold text-danger"
                    >
                      <.icon name="hero-exclamation-triangle" class="size-4 shrink-0" />
                      Supplier is not answering
                    </p>
                    <p
                      :if={f.escalation_level == 2 and f.status in [:pending, :notified]}
                      class="flex items-center gap-1.5 font-semibold text-warning"
                    >
                      <.icon name="hero-clock" class="size-4 shrink-0" /> Still no reply
                    </p>
                    <p
                      :if={f.status == :delivered and not f.delivery_verified}
                      class="flex items-center gap-1.5 font-semibold text-warning"
                    >
                      <.icon name="hero-shield-exclamation" class="size-4 shrink-0" />
                      No customer proof
                    </p>
                    <p
                      :if={f.status == :delivered and f.delivery_verified}
                      class="flex items-center gap-1.5 font-semibold text-success"
                    >
                      <.icon name="hero-shield-check" class="size-4 shrink-0" /> Customer confirmed
                    </p>
                  </div>

                  <%!-- A failed send used to live only in oban_jobs, where no
                        merchant will ever look, so the fulfilment sat pending
                        forever and nobody knew the supplier never heard. The
                        label itself is for the logs; the merchant gets the
                        sentence and something to do about it. --%>
                  <div
                    :if={f.last_send_error && f.status == :pending}
                    class="flex flex-wrap items-center gap-2 rounded-control bg-danger-soft p-2 text-xs font-semibold text-danger"
                  >
                    <.icon name="hero-signal-slash" class="size-4 shrink-0" />
                    <span :if={f.last_send_error == "no_contact"}>
                      No phone number for this supplier
                    </span>
                    <span :if={f.last_send_error != "no_contact"}>
                      Message not delivered
                    </span>
                  </div>

                  <%!-- The supplier has no account, so the link IS the delivery
                        mechanism. It works whether it arrives by WhatsApp
                        Business, by SMS, or by the merchant pasting it into
                        their own chat — which is what makes this usable while
                        the automated rails are still unreliable. --%>
                  <div
                    :if={not is_nil(f.supplier_id) and f.status in [:pending, :notified, :declined]}
                    data-role="supplier-link"
                    class="flex flex-wrap items-center gap-2 rounded-control bg-surface-subtle p-2"
                  >
                    <.admin_button
                      variant={:secondary}
                      size={:sm}
                      phx-click={
                        JS.dispatch("copy-to-clipboard",
                          detail: %{text: @supplier_links[f.id]}
                        )
                      }
                    >
                      Copy supplier link
                    </.admin_button>
                    <a
                      :if={f.supplier && f.supplier.whatsapp_number}
                      href={whatsapp_share_url(f, @supplier_links[f.id])}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 bg-success hover:bg-success text-white rounded-control text-xs font-semibold transition-colors"
                    >
                      Send on WhatsApp
                    </a>
                    <.admin_button
                      variant={:secondary}
                      size={:sm}
                      phx-click="rotate_supplier_link"
                      phx-value-id={f.id}
                      data-confirm="The old link will stop working. Continue?"
                    >
                      New link
                    </.admin_button>
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
                    <%!-- Gated on accepted_at, not status: an accept leaves the
                          status at :notified on purpose, so keying on status
                          alone would keep offering "Resend" for a supplier who
                          has already said yes. --%>
                    <.admin_button
                      :if={
                        not is_nil(f.supplier_id) and f.status in [:pending, :notified] and
                          is_nil(f.accepted_at)
                      }
                      size={:sm}
                      phx-click="send_supplier_fulfillment"
                      phx-value-id={f.id}
                    >
                      {cond do
                        f.last_send_error -> "Try again"
                        f.status == :notified -> "Resend"
                        true -> "Send to supplier"
                      end}
                    </.admin_button>
                    <button
                      :if={f.status in [:pending, :notified, :declined]}
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
                    <%!-- The escape hatch, and it stays one: there is no
                          auto-release timer, so a merchant whose buyer never
                          answers has no other way forward. It is kept quiet,
                          asks first, and leaves a record. --%>
                    <button
                      :if={f.status == :shipped}
                      phx-click="deliver_fulfillment"
                      phx-value-id={f.id}
                      data-confirm="Only do this if you cannot reach the customer. It will be recorded as delivered without proof."
                      class="inline-flex items-center gap-1.5 px-3 py-1.5 text-slate-500 hover:text-slate-700 rounded-control text-xs font-medium underline underline-offset-2 transition-colors"
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
            phx-submit={JS.push("submit_shipped") |> hide_modal("shipped-order-modal")}
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

        socket
        |> assign(fulfillments: fulfillments)
        |> assign(supplier_links: supplier_links(fulfillments))
    end
  end

  # Signed once per load and stashed, never in render/1: each URL is an HMAC and
  # the fulfilment list re-renders on every LiveView diff.
  defp supplier_links(fulfillments) do
    fulfillments
    |> Enum.filter(& &1.supplier_id)
    |> Map.new(&{&1.id, Emakola.Suppliers.SupplierAction.action_url(&1)})
  end

  # Best-effort and deliberately after the cancel: the cancellation is the thing
  # the merchant asked for, and a ledger hiccup must not undo it. An entry the
  # platform already claimed is left alone — that debt is settled by a rail this
  # button has no business touching.
  defp void_unfulfilled_debt(fulfillment_id) do
    case Emakola.Suppliers.list_supplier_ledger_entries_by_fulfillment(fulfillment_id,
           authorize?: false
         ) do
      {:ok, entries} ->
        Enum.each(entries, fn entry ->
          Emakola.Suppliers.void_unfulfilled_supplier_ledger_entry(entry, authorize?: false)
        end)

      {:error, reason} ->
        Logger.error(
          "[order_live.show] could not load ledger entries for #{fulfillment_id}: #{inspect(reason)}"
        )
    end
  rescue
    exception ->
      Logger.error(
        "[order_live.show] void_unfulfilled_debt raised for #{fulfillment_id}: #{Exception.message(exception)}"
      )

      :ok
  end

  defp attesting_merchant_id(socket) do
    case socket.assigns[:current_merchant] do
      %{id: id} -> id
      _ -> nil
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

          # No :mark_delivered clause. Nothing in this LiveView reaches it any
          # more: the merchant's own button now goes through
          # :self_attest_delivered, and the proven path runs inside
          # CustomerDelivery.verify_delivery/3 off the buyer's code. Dialyzer
          # flags the dead clause, and it is right to.
          :self_attest_delivered ->
            Emakola.Orders.self_attest_fulfillment_delivered(fulfillment, params,
              authorize?: false
            )

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

  # A deep link to THIS supplier's number, not a generic share sheet — the
  # merchant should not have to pick the right chat out of a list.
  defp whatsapp_share_url(fulfillment, action_url) do
    digits = String.replace(fulfillment.supplier.whatsapp_number || "", ~r/\D/, "")

    text =
      "Order #{order_number_for(fulfillment)}: please open this to accept or decline. #{action_url}"

    "https://wa.me/#{digits}?text=#{URI.encode(text)}"
  end

  defp order_number_for(%{order: %{order_number: number}}) when is_binary(number), do: number
  defp order_number_for(_fulfillment), do: ""

  defp fulfillment_badge_class(:pending), do: "bg-warning-soft text-warning"
  defp fulfillment_badge_class(:notified), do: "bg-info-soft text-info"
  defp fulfillment_badge_class(:shipped), do: "bg-purple-50 text-purple-700"
  defp fulfillment_badge_class(:delivered), do: "bg-success-soft text-success"
  defp fulfillment_badge_class(:cancelled), do: "bg-danger-soft text-danger"
  defp fulfillment_badge_class(:declined), do: "bg-danger-soft text-danger"
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
