defmodule EmakolaWeb.Admin.ReturnLive do
  @moduledoc """
  Merchant admin page for managing return requests.

  Lists all returns for the store with status filtering,
  and provides approve/deny/refund actions with notes.
  """

  use EmakolaWeb, :live_view

  import EmakolaWeb.ReturnComponents

  alias EmakolaWeb.Helpers.Currency

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns[:current_store]

    case store do
      nil ->
        {:ok,
         socket
         |> assign(page_title: "Returns", active_nav: :returns)
         |> put_flash(:error, "Please set up your store first.")
         |> redirect(to: "/onboarding")}

      store ->
        returns = load_returns(store.id)

        {:ok,
         socket
         |> assign(
           page_title: "Returns",
           active_nav: :returns,
           store: store,
           returns: returns,
           status_filter: "all",
           selected_return: nil,
           action_notes: "",
           refund_amount_input: "",
           refund_dispatch_fee: false,
           selected_payment: nil,
           selected_fulfillments: []
         )}
    end
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    returns = load_returns(socket.assigns.store.id, status)

    {:noreply,
     assign(socket,
       returns: returns,
       status_filter: status
     )}
  end

  @impl true
  def handle_event("select_return", %{"id" => id}, socket) do
    selected = Enum.find(socket.assigns.returns, &(&1.id == id))
    {payment, fulfillments} = load_refund_context(socket, selected)

    {:noreply,
     assign(socket,
       selected_return: selected,
       action_notes: "",
       refund_amount_input: "",
       refund_dispatch_fee: false,
       selected_payment: payment,
       selected_fulfillments: fulfillments
     )}
  end

  @impl true
  def handle_event("close_detail", _params, socket) do
    {:noreply, assign(socket, selected_return: nil)}
  end

  @impl true
  def handle_event("update_notes", %{"notes" => notes}, socket) do
    {:noreply, assign(socket, action_notes: notes)}
  end

  @impl true
  def handle_event("update_refund_amount", %{"amount" => amount}, socket) do
    {:noreply, assign(socket, refund_amount_input: amount)}
  end

  @impl true
  def handle_event("noop_submit", _params, socket) do
    # The notes/amount inputs live in their own <form> so LiveView can send
    # phx-change events (browsers refuse phx-change from an input with no
    # form ancestor). Neither form has a submit button, but pressing Enter
    # while focused in one still fires a submit — this swallows it so Enter
    # can never trigger a refund.
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_dispatch_fee", _params, socket) do
    {:noreply, assign(socket, refund_dispatch_fee: !socket.assigns.refund_dispatch_fee)}
  end

  @impl true
  def handle_event("approve_return", _params, %{assigns: %{selected_return: nil}} = socket) do
    # A double click queues a second approve that lands after the first one
    # cleared the selection. There is nothing left to approve, and reaching the
    # service with nil used to kill the LiveView.
    {:noreply, socket}
  end

  @impl true
  def handle_event("approve_return", _params, socket) do
    # Approving a return sends the customer's money back through the gateway,
    # so it goes through RefundService with the merchant as actor. A blank or
    # unparseable amount becomes nil and the service refuses it — this used to
    # be `Float.parse`, which silently approved a return that refunded nothing.
    refund_amount =
      case Emakola.Money.parse_price(socket.assigns.refund_amount_input) do
        {:ok, pesewas} -> pesewas
        _ -> nil
      end

    params = %{
      admin_notes: socket.assigns.action_notes,
      refund_amount: refund_amount,
      refund_dispatch_fee?: socket.assigns.refund_dispatch_fee
    }

    case Emakola.Payments.RefundService.issue(
           socket.assigns.current_merchant,
           socket.assigns.selected_return,
           params
         ) do
      {:ok, _updated} ->
        returns = load_returns(socket.assigns.store.id, socket.assigns.status_filter)

        {:noreply,
         socket
         |> assign(returns: returns, selected_return: nil)
         |> put_flash(:info, "Return approved")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, refund_error(reason))}
    end
  end

  @impl true
  def handle_event("deny_return", _params, socket) do
    return = socket.assigns.selected_return

    case Emakola.Orders.deny_return(
           return,
           %{admin_notes: socket.assigns.action_notes},
           authorize?: false
         ) do
      {:ok, _updated} ->
        returns = load_returns(socket.assigns.store.id, socket.assigns.status_filter)

        {:noreply,
         socket
         |> assign(returns: returns, selected_return: nil)
         |> put_flash(:info, "Return denied")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to deny return")}
    end
  end

  @impl true
  def handle_event("mark_refunded", _params, socket) do
    return = socket.assigns.selected_return

    case Emakola.Orders.mark_return_refunded(return, authorize?: false) do
      {:ok, _updated} ->
        returns = load_returns(socket.assigns.store.id, socket.assigns.status_filter)

        {:noreply,
         socket
         |> assign(returns: returns, selected_return: nil)
         |> put_flash(:info, "Return marked as refunded")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to mark as refunded")}
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assigns
      |> assign(:refundable_balance, refundable_balance(assigns.selected_payment))
      |> assign(:supplier_fulfillments, supplier_fulfillments(assigns.selected_fulfillments))
      |> assign(
        :show_dispatch_toggle?,
        not is_nil(assigns.selected_payment) and
          Enum.any?(assigns.selected_fulfillments, &dispatched?/1)
      )
      |> assign(
        :suggested_max,
        suggested_max(
          assigns.selected_payment,
          assigns.selected_fulfillments,
          assigns.refund_dispatch_fee
        )
      )
      |> assign(
        :amount_exceeds_suggested_max?,
        exceeds_suggested_max?(
          assigns.refund_amount_input,
          assigns.selected_payment,
          assigns.selected_fulfillments,
          assigns.refund_dispatch_fee
        )
      )

    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header
        title="Returns"
        subtitle="Review and manage customer return requests"
      />

      <%!-- Status filter tabs --%>
      <div class="flex gap-2 overflow-x-auto pb-1">
        <button
          :for={status <- ["all", "requested", "approved", "denied", "refunded"]}
          phx-click="filter_status"
          phx-value-status={status}
          class={[
            "cursor-pointer whitespace-nowrap px-4 py-2 text-sm font-medium rounded-full border transition-colors",
            if(@status_filter == status,
              do: "bg-cta-dark text-white border-[#1C1917]",
              else: "bg-white text-stone-600 border-stone-200 hover:border-stone-400"
            )
          ]}
        >
          {String.capitalize(status)}
        </button>
      </div>

      <%!-- Returns list --%>
      <div :if={@returns == []} class="bg-white rounded-2xl shadow-sm p-12 text-center">
        <svg
          class="mx-auto w-12 h-12 text-stone-300 mb-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="1.5"
            d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
          />
        </svg>
        <h3 class="text-lg font-semibold text-stone-700">No returns found</h3>
        <p class="text-sm text-stone-500 mt-1">Return requests from customers will appear here</p>
      </div>

      <div :if={@returns != []} class="space-y-3">
        <div
          :for={return <- @returns}
          phx-click="select_return"
          phx-value-id={return.id}
          class={[
            "bg-white rounded-2xl shadow-sm p-5 cursor-pointer transition-all hover:shadow-md",
            if(@selected_return && @selected_return.id == return.id,
              do: "ring-2 ring-amber-700",
              else: ""
            )
          ]}
        >
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-3">
            <div class="flex items-center gap-4">
              <div class="w-10 h-10 rounded-lg bg-stone-100 flex items-center justify-center flex-shrink-0">
                <svg
                  class="w-5 h-5 text-stone-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="1.5"
                    d="M9 15L3 9m0 0l6-6M3 9h12a6 6 0 010 12h-3"
                  />
                </svg>
              </div>
              <div>
                <p class="text-sm font-semibold text-cta-dark">
                  Order #{return.order_id |> String.slice(0..7)}
                </p>
                <p class="text-xs text-stone-500 mt-0.5">
                  <.reason_label reason={return.reason} />
                  <span :if={return.reason_detail}>
                    -- {String.slice(return.reason_detail, 0..60)}
                  </span>
                </p>
              </div>
            </div>
            <div class="flex items-center gap-4">
              <span :if={return.refund_amount} class="text-sm font-medium text-cta-dark">
                {Currency.format_price(return.refund_amount, return.currency)}
              </span>
              <.return_status_badge status={return.status} />
            </div>
          </div>
        </div>
      </div>

      <%!-- Detail panel --%>
      <div
        :if={@selected_return}
        class="bg-white rounded-2xl shadow-sm p-6 space-y-6"
      >
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold text-cta-dark">Return Details</h2>
          <button
            phx-click="close_detail"
            class="cursor-pointer text-stone-400 hover:text-stone-600 transition-colors"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M6 18L18 6M6 6l12 12"
              />
            </svg>
          </button>
        </div>

        <%!-- Timeline --%>
        <div class="flex justify-center py-2">
          <.return_timeline status={@selected_return.status} />
        </div>

        <%!-- Info grid --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <p class="text-xs font-medium uppercase tracking-wider text-stone-500 mb-1">Reason</p>
            <p class="text-sm text-cta-dark"><.reason_label reason={@selected_return.reason} /></p>
          </div>
          <div>
            <p class="text-xs font-medium uppercase tracking-wider text-stone-500 mb-1">Status</p>
            <.return_status_badge status={@selected_return.status} />
          </div>
          <div :if={@selected_return.reason_detail} class="sm:col-span-2">
            <p class="text-xs font-medium uppercase tracking-wider text-stone-500 mb-1">Details</p>
            <p class="text-sm text-cta-dark">{@selected_return.reason_detail}</p>
          </div>
          <div :if={@selected_return.admin_notes} class="sm:col-span-2">
            <p class="text-xs font-medium uppercase tracking-wider text-stone-500 mb-1">
              Admin Notes
            </p>
            <p class="text-sm text-cta-dark">{@selected_return.admin_notes}</p>
          </div>
          <div :if={@selected_return.refund_amount}>
            <p class="text-xs font-medium uppercase tracking-wider text-stone-500 mb-1">
              Refund Amount
            </p>
            <p class="text-sm font-semibold text-cta-dark">
              {Currency.format_price(@selected_return.refund_amount, @selected_return.currency)}
            </p>
          </div>
        </div>

        <%!-- Actions for requested returns --%>
        <div
          :if={@selected_return.status == :requested}
          class="space-y-4 border-t border-stone-100 pt-4"
        >
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider text-stone-500 mb-2">
              Notes
            </label>
            <form phx-submit="noop_submit" class="contents">
              <textarea
                phx-change="update_notes"
                name="notes"
                rows="3"
                placeholder="Add notes about this decision..."
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:ring-2 focus:ring-amber-700 focus:border-amber-700 focus:outline-none"
              >{@action_notes}</textarea>
            </form>
          </div>
          <%!-- Refund guidance --%>
          <div :if={@selected_payment} class="space-y-3">
            <.stat_card
              label="Refundable balance"
              value={Currency.format_price(@refundable_balance, @selected_return.currency)}
            />

            <div
              :if={@supplier_fulfillments != []}
              class="rounded-2xl border border-stone-200 divide-y divide-stone-100"
            >
              <div
                :for={f <- @supplier_fulfillments}
                class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-1 sm:gap-3 px-4 py-3"
              >
                <div class="min-w-0 flex items-center gap-2">
                  <p class="text-sm font-medium text-cta-dark truncate">{f.supplier.name}</p>
                  <.status_badge status={f.status} variant={:delivery} />
                </div>
                <span class="text-sm font-semibold text-cta-dark">
                  {Currency.format_price(f.dispatch_fee, @selected_return.currency)}
                </span>
              </div>
            </div>
          </div>
          <p :if={is_nil(@selected_payment)} class="text-sm text-stone-500">
            No gateway payment on this order — there is nothing to refund automatically.
          </p>

          <div>
            <label class="block text-xs font-medium uppercase tracking-wider text-stone-500 mb-2">
              Refund Amount (GHS)
            </label>
            <form phx-submit="noop_submit" class="contents">
              <input
                type="text"
                phx-change="update_refund_amount"
                name="amount"
                value={@refund_amount_input}
                placeholder="0.00"
                class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:ring-2 focus:ring-amber-700 focus:border-amber-700 focus:outline-none"
              />
            </form>
            <p :if={@amount_exceeds_suggested_max?} class="mt-2 text-xs font-medium text-amber-700">
              Above the suggested limit of {Currency.format_price(
                @suggested_max,
                @selected_return.currency
              )} — this refund would dip into a dispatched supplier's protected dispatch fee.
            </p>
          </div>
          <label
            :if={@show_dispatch_toggle?}
            class="flex items-start gap-3 cursor-pointer rounded-2xl border border-stone-200 px-4 py-3 hover:border-amber-300 transition-colors"
          >
            <input
              type="checkbox"
              phx-click="toggle_dispatch_fee"
              checked={@refund_dispatch_fee}
              class="mt-0.5 w-4 h-4 rounded border-stone-300 text-amber-700 focus:ring-amber-700"
            />
            <span class="text-sm text-cta-dark">
              Supplier is at fault — also refund their dispatch fee
            </span>
          </label>
          <div class="flex gap-3">
            <button
              phx-click="approve_return"
              phx-disable-with="Approving..."
              class="cursor-pointer bg-green-600 text-white text-xs font-semibold uppercase tracking-wider px-6 py-2.5 rounded-[20px] hover:bg-green-700 transition-colors"
            >
              Approve
            </button>
            <button
              phx-click="deny_return"
              class="cursor-pointer bg-red-600 text-white text-xs font-semibold uppercase tracking-wider px-6 py-2.5 rounded-[20px] hover:bg-red-700 transition-colors"
            >
              Deny
            </button>
          </div>
        </div>

        <%!-- Action for approved returns --%>
        <div :if={@selected_return.status == :approved} class="border-t border-stone-100 pt-4">
          <button
            phx-click="mark_refunded"
            class="cursor-pointer bg-emerald-600 text-white text-xs font-semibold uppercase tracking-wider px-6 py-2.5 rounded-[20px] hover:bg-emerald-700 transition-colors"
          >
            Mark as Refunded
          </button>
        </div>
      </div>
    </div>
    """
  end

  # -- Private --

  defp refund_error(:already_processed),
    do: "This return has already been handled — reload the page to see where it stands."

  defp refund_error(:gateway_unsupported),
    do: "Refunds for this payment must be issued in the provider dashboard."

  defp refund_error(:amount_exceeds_refundable),
    do: "That is more than the amount still refundable on this payment."

  defp refund_error(:payment_not_found),
    do: "No payment was found for this order, so there is nothing to refund."

  defp refund_error(:invalid_amount),
    do: "Enter the amount to refund in GHS, for example 48.50."

  defp refund_error(_reason), do: "Failed to approve return"

  defp load_returns(store_id, status_filter \\ "all") do
    returns = Emakola.Orders.list_returns_by_store!(store_id, authorize?: false)

    case status_filter do
      "all" -> returns
      status -> Enum.filter(returns, &(Atom.to_string(&1.status) == status))
    end
  end

  # Loaded once when a return is selected, not per render — the guidance
  # panel only appears for requested returns, so nothing else needs it.
  defp load_refund_context(socket, %{status: :requested} = return) do
    opts = [actor: socket.assigns.current_merchant, tenant: return.store_id]

    payment =
      case Emakola.Payments.get_payment_by_order(
             return.order_id,
             opts ++ [not_found_error?: false]
           ) do
        {:ok, payment} -> payment
        _ -> nil
      end

    fulfillments = Emakola.Orders.list_fulfillments_by_order!(return.order_id, opts)

    {payment, fulfillments}
  end

  defp load_refund_context(_socket, _return), do: {nil, []}

  defp dispatched?(%{status: status}), do: status in [:shipped, :delivered]

  defp supplier_fulfillments(fulfillments), do: Enum.filter(fulfillments, & &1.supplier_id)

  defp protected_dispatch_fees(fulfillments) do
    fulfillments
    |> Enum.filter(&dispatched?/1)
    |> Enum.map(& &1.dispatch_fee)
    |> Enum.sum()
  end

  defp refundable_balance(nil), do: nil
  defp refundable_balance(payment), do: payment.amount - (payment.refunded_amount || 0)

  defp suggested_max(nil, _fulfillments, _waived?), do: nil

  defp suggested_max(payment, fulfillments, waived?) do
    protected = if waived?, do: 0, else: protected_dispatch_fees(fulfillments)
    max(refundable_balance(payment) - protected, 0)
  end

  defp exceeds_suggested_max?(_input, nil, _fulfillments, _waived?), do: false

  defp exceeds_suggested_max?(input, payment, fulfillments, waived?) do
    case Emakola.Money.parse_price(input) do
      {:ok, pesewas} -> pesewas > suggested_max(payment, fulfillments, waived?)
      _ -> false
    end
  end
end
