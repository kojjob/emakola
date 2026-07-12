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
           refund_amount_input: ""
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

    {:noreply,
     assign(socket,
       selected_return: selected,
       action_notes: "",
       refund_amount_input: ""
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
  def handle_event("approve_return", _params, socket) do
    return = socket.assigns.selected_return

    refund_amount =
      case Float.parse(socket.assigns.refund_amount_input) do
        {amount, _} -> round(amount * 100)
        :error -> nil
      end

    case Emakola.Orders.approve_return(
           return,
           %{admin_notes: socket.assigns.action_notes, refund_amount: refund_amount},
           authorize?: false
         ) do
      {:ok, _updated} ->
        returns = load_returns(socket.assigns.store.id, socket.assigns.status_filter)

        {:noreply,
         socket
         |> assign(returns: returns, selected_return: nil)
         |> put_flash(:info, "Return approved")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Failed to approve return")}
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
            <textarea
              phx-change="update_notes"
              name="notes"
              rows="3"
              placeholder="Add notes about this decision..."
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:ring-2 focus:ring-amber-700 focus:border-amber-700 focus:outline-none"
            >{@action_notes}</textarea>
          </div>
          <div>
            <label class="block text-xs font-medium uppercase tracking-wider text-stone-500 mb-2">
              Refund Amount (GHS)
            </label>
            <input
              type="text"
              phx-change="update_refund_amount"
              name="amount"
              value={@refund_amount_input}
              placeholder="0.00"
              class="w-full px-4 py-3 border border-stone-200 rounded-lg text-sm text-cta-dark focus:ring-2 focus:ring-amber-700 focus:border-amber-700 focus:outline-none"
            />
          </div>
          <div class="flex gap-3">
            <button
              phx-click="approve_return"
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

  defp load_returns(store_id, status_filter \\ "all") do
    returns = Emakola.Orders.list_returns_by_store!(store_id, authorize?: false)

    case status_filter do
      "all" -> returns
      status -> Enum.filter(returns, &(Atom.to_string(&1.status) == status))
    end
  end
end
