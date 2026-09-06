defmodule EmakolaWeb.Admin.CustomerLive.Show do
  @moduledoc """
  Customer detail page: header info, order history, total spent,
  edit customer info, and notes.
  """
  use EmakolaWeb, :live_view

  require Logger

  import EmakolaWeb.Helpers.Currency, only: [format_price: 1]

  import EmakolaWeb.Admin.CustomerLive.Components,
    only: [
      customer_initials: 1,
      order_status_badge: 1,
      delivery_and_problems: 1,
      notes_panel: 1
    ]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    store_id = socket.assigns.current_store.id

    case load_customer(id, store_id) do
      {:ok, customer} ->
        orders = load_orders(customer.id, customer.store_id)
        paid_orders = Enum.filter(orders, &(&1.status in Emakola.Orders.Order.paid_statuses()))
        total_spent = paid_orders |> Enum.map(& &1.total) |> Enum.sum()
        paid_count = length(paid_orders)
        cancelled_count = Enum.count(orders, &(&1.status == :cancelled))

        addresses =
          Emakola.Customers.list_addresses_by_customer_and_store!(customer.id, store_id,
            authorize?: false
          )

        address = Enum.find(addresses, & &1.is_default) || List.first(addresses)

        socket =
          socket
          |> assign(
            page_title: customer.name || "Customer",
            active_nav: :customers,
            customer: customer,
            orders: orders,
            show_all_orders?: false,
            total_spent: total_spent,
            paid_count: paid_count,
            cancelled_count: cancelled_count,
            address: address,
            returns_count: count_returns(customer.id, store_id),
            failed_payments: count_failed_payments(customer, store_id),
            notes: list_notes(customer.id, store_id),
            note_form: blank_note_form(),
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

  def handle_event("show_all_orders", _params, socket) do
    {:noreply, assign(socket, show_all_orders?: true)}
  end

  def handle_event("add_note", %{"note" => %{"content" => content}}, socket) do
    %{customer: customer, current_store: store, current_merchant: merchant} = socket.assigns

    case Emakola.Customers.create_note(
           %{
             customer_id: customer.id,
             store_id: store.id,
             author_id: merchant.id,
             content: content
           },
           authorize?: false
         ) do
      {:ok, _note} -> {:noreply, socket |> reload_notes() |> assign(note_form: blank_note_form())}
      {:error, _error} -> {:noreply, put_flash(socket, :error, "Write something first")}
    end
  end

  def handle_event("remove_note", %{"id" => id}, socket) do
    %{customer: customer, current_store: store} = socket.assigns

    socket.assigns.notes
    |> Enum.find(&(&1.id == id and &1.customer_id == customer.id and &1.store_id == store.id))
    |> case do
      nil ->
        {:noreply, socket}

      note ->
        case destroy_note(note) do
          :ok ->
            {:noreply, reload_notes(socket)}

          {:error, error} ->
            Logger.warning(
              "[customer_live.show] failed to remove note #{note.id} (store #{store.id}): #{Exception.message(error)}"
            )

            {:noreply, put_flash(socket, :error, "Could not remove that note")}
        end
    end
  end

  def handle_event("open_thread", _params, socket) do
    %{customer: customer, current_store: store} = socket.assigns

    # Matched, not asserted: a hard `{:ok, thread} =` turned any error into a
    # MatchError that took the whole page down, losing the merchant whatever
    # else was on it.
    case Emakola.Conversations.open_shop_thread(store.id, customer.id) do
      {:ok, thread} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/messages/#{thread.id}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not open that chat. Please try again.")}
    end
  end

  @impl true
  def handle_event("save_customer", %{"customer" => params}, socket) do
    case Emakola.Customers.update_customer(socket.assigns.customer, params, authorize?: false) do
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
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%!-- Back link --%>
      <.link
        navigate={~p"/admin/customers"}
        class="inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-700 transition-colors"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Back to Customers
      </.link>

      <%!-- Customer Header --%>
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4">
          <div class="flex items-center gap-4">
            <div class="w-14 h-14 rounded-full bg-emerald-100 flex items-center justify-center flex-shrink-0">
              <span class="text-xl font-bold text-emerald-700">
                {customer_initials(@customer.name)}
              </span>
            </div>
            <div>
              <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">
                {@customer.name || "Unnamed"}
              </h1>
              <p class="text-sm text-slate-500">{@customer.email}</p>
              <p :if={@customer.phone} class="text-sm text-slate-500">{@customer.phone}</p>
              <p class="text-xs text-slate-400 mt-1">
                Member since {Calendar.strftime(@customer.inserted_at, "%B %d, %Y")}
              </p>
              <p :if={@customer.last_order_at} class="text-sm text-slate-500">
                Last bought {Calendar.strftime(@customer.last_order_at, "%d %b %Y")}
              </p>
              <p
                :if={@customer.marketing_opt_out_at}
                id="customer-opt-out"
                class="text-xs font-semibold text-amber-700 mt-1"
              >
                No marketing messages
              </p>
              <div :if={@customer.tags != []} id="customer-tags" class="flex flex-wrap gap-1.5 mt-2">
                <span
                  :for={tag <- @customer.tags}
                  class="text-xs font-semibold px-2 py-0.5 rounded-full bg-slate-100 text-slate-700"
                >
                  {tag}
                </span>
              </div>
            </div>
          </div>
          <div class="flex items-center gap-2">
            <a
              :if={@customer.phone}
              href={"https://wa.me/#{String.replace(@customer.phone, ~r/\D/, "")}"}
              target="_blank"
              rel="noopener"
              class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors"
            >
              <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" /> WhatsApp
            </a>
            <button
              id="customer-message"
              type="button"
              phx-click="open_thread"
              class="inline-flex items-center gap-2 px-4 py-2 bg-emerald-600 text-white rounded-xl text-sm font-semibold hover:bg-emerald-700 transition-colors cursor-pointer"
            >
              <.icon name="hero-chat-bubble-left-right" class="size-4" /> Message
            </button>
            <button
              phx-click="toggle_edit"
              class="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
            >
              <.icon name="hero-pencil-square" class="size-4" /> Edit
            </button>
          </div>
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
        <div class="bg-white rounded-2xl shadow-sm p-5">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Total Spent
          </span>
          <p class="text-2xl font-bold text-slate-900 font-mono mt-2">{format_price(@total_spent)}</p>
        </div>
        <div class="bg-white rounded-2xl shadow-sm p-5">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Paid Orders
          </span>
          <p class="text-2xl font-bold text-slate-900 font-mono mt-2">{@paid_count}</p>
        </div>
        <div class="bg-white rounded-2xl shadow-sm p-5">
          <span class="text-xs font-semibold text-slate-500 uppercase tracking-wider">
            Avg. Order
          </span>
          <p class="text-2xl font-bold text-slate-900 font-mono mt-2">
            {format_avg_order(@total_spent, @paid_count)}
          </p>
        </div>
      </div>

      <.delivery_and_problems
        address={@address}
        returns_count={@returns_count}
        cancelled_count={@cancelled_count}
        failed_payments={@failed_payments}
      />

      <%!-- Order History --%>
      <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
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
                  :for={order <- visible_orders(@orders, @show_all_orders?)}
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
          <div :if={not @show_all_orders? and length(@orders) > 20} class="px-6 py-4 text-center">
            <.admin_button id="show-all-orders" variant={:secondary} phx-click="show_all_orders">
              Show all
            </.admin_button>
          </div>
        <% end %>
      </div>

      <%!-- Notes --%>
      <.notes_panel note_form={@note_form} notes={@notes} />
    </div>
    """
  end

  # ── Data Loading ──

  defp load_customer(id, store_id) do
    Emakola.Customers.get_customer_by_id_for_store(id, store_id, authorize?: false)
  end

  defp load_orders(customer_id, store_id) do
    Emakola.Orders.list_orders_by_customer!(customer_id, store_id, authorize?: false)
  rescue
    exception ->
      Logger.error(
        "[customer_live.show] load_orders loading customer orders raised: #{Exception.message(exception)}"
      )

      []
  end

  defp list_notes(customer_id, store_id) do
    Emakola.Customers.list_notes_by_customer_and_store!(customer_id, store_id, authorize?: false)
  end

  defp count_returns(customer_id, store_id) do
    customer_id
    |> Emakola.Orders.list_returns_by_customer_and_store!(store_id, authorize?: false)
    |> length()
  end

  defp count_failed_payments(%{email: nil}, _store_id), do: 0

  defp count_failed_payments(customer, store_id) do
    require Ash.Query

    # customer_email is whatever case the buyer typed at checkout; Customer's
    # email is a :ci_string. Compare lowercased so a case difference doesn't
    # silently undercount.
    Emakola.Payments.Payment
    |> Ash.Query.filter(
      store_id == ^store_id and
        fragment("lower(?)", customer_email) == ^String.downcase(to_string(customer.email)) and
        status == :failed
    )
    |> Ash.count!(authorize?: false)
  end

  defp reload_notes(socket) do
    %{customer: customer, current_store: store} = socket.assigns
    assign(socket, notes: list_notes(customer.id, store.id))
  end

  defp blank_note_form, do: to_form(%{"content" => ""}, as: :note)

  defp destroy_note(note) do
    case Emakola.Customers.destroy_note(note, authorize?: false) do
      :ok ->
        :ok

      {:ok, _note} ->
        :ok

      {:error, error} ->
        if stale_or_not_found?(error) do
          # Already gone (e.g. removed from another session) — nothing left
          # to do.
          :ok
        else
          {:error, error}
        end
    end
  end

  defp stale_or_not_found?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, fn
      %Ash.Error.Changes.StaleRecord{} -> true
      %Ash.Error.Query.NotFound{} -> true
      _ -> false
    end)
  end

  defp stale_or_not_found?(_error), do: false

  # ── Helpers ──

  defp format_avg_order(_total, 0), do: format_price(0)
  defp format_avg_order(total, count), do: format_price(div(total, count))

  defp visible_orders(orders, true), do: orders
  defp visible_orders(orders, false), do: Enum.take(orders, 20)
end
