defmodule EmakolaWeb.Admin.SupplierLive.Show do
  @moduledoc """
  Supplier detail page — shows contact/payment info, the outstanding payout
  balance, and the payout ledger. Owed entries can be marked paid, which
  reduces the outstanding balance.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  require Ash.Query

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Supplier",
        active_nav: :suppliers,
        store: store,
        supplier_id: id,
        supplier: nil,
        ledger_entries: []
      )
      |> load_supplier()
      |> load_ledger()

    {:ok, socket}
  end

  @impl true
  def handle_event("mark_paid", %{"id" => entry_id}, socket) do
    entry = Enum.find(socket.assigns.ledger_entries, &(&1.id == entry_id))

    if entry do
      case entry
           |> Ash.Changeset.for_update(:mark_paid, %{})
           |> Ash.update(authorize?: false) do
        {:ok, _} ->
          {:noreply,
           socket
           |> load_supplier()
           |> load_ledger()
           |> put_flash(:info, "Entry marked paid")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not mark entry paid")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Data loading ──

  defp load_supplier(socket) do
    %{supplier_id: id, store: store} = socket.assigns

    supplier =
      if store do
        case Emakola.Suppliers.Supplier
             |> Ash.Query.filter(id == ^id and store_id == ^store.id)
             |> Ash.Query.load(:outstanding_balance)
             |> Ash.read(authorize?: false) do
          {:ok, [supplier]} -> supplier
          _ -> nil
        end
      end

    assign(socket,
      supplier: supplier,
      page_title: if(supplier, do: supplier.name, else: "Supplier Not Found")
    )
  end

  defp load_ledger(socket) do
    case socket.assigns.supplier do
      nil ->
        assign(socket, ledger_entries: [])

      supplier ->
        entries =
          Emakola.Suppliers.list_ledger_entries_by_supplier!(supplier.id, authorize?: false)

        assign(socket, ledger_entries: entries)
    end
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y at %H:%M")
  defp format_datetime(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%d %b %Y at %H:%M")
  defp format_datetime(_), do: "—"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <div class="flex items-center gap-2">
        <.link navigate={~p"/admin/settings/suppliers"} class="text-slate-400 hover:text-slate-600">
          <.icon name="hero-arrow-left" class="size-4" />
        </.link>
        <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">
          {if @supplier, do: @supplier.name, else: "Supplier Not Found"}
        </h1>
      </div>

      <%= if @supplier do %>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <%!-- Details --%>
          <.admin_card padding={:none} class="p-5 space-y-3">
            <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">
              Contact
            </h2>
            <p :if={@supplier.contact_phone} class="text-sm text-slate-700">
              <span class="text-slate-400">Phone:</span> {@supplier.contact_phone}
            </p>
            <p :if={@supplier.whatsapp_number} class="text-sm text-slate-700">
              <span class="text-slate-400">WhatsApp:</span> {@supplier.whatsapp_number}
            </p>
            <p :if={@supplier.contact_email} class="text-sm text-slate-700">
              <span class="text-slate-400">Email:</span> {@supplier.contact_email}
            </p>
            <p :if={@supplier.payment_details["info"]} class="text-sm text-slate-700">
              <span class="text-slate-400">Payment:</span> {@supplier.payment_details["info"]}
            </p>
            <p :if={@supplier.notes} class="text-sm text-slate-500 pt-2 border-t border-slate-100">
              {@supplier.notes}
            </p>
          </.admin_card>

          <%!-- Balance --%>
          <.admin_card padding={:none} class="p-5 lg:col-span-2">
            <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide mb-2">
              Outstanding Balance
            </h2>
            <p id="outstanding-balance" class="text-3xl font-bold text-slate-900 font-mono">
              {format_price(@supplier.outstanding_balance || 0, "GHS")}
            </p>
            <p class="text-sm text-slate-500 mt-1">Total still owed across unpaid ledger entries</p>
          </.admin_card>
        </div>

        <%!-- Ledger --%>
        <.admin_card padding={:none} class="overflow-hidden">
          <div class="px-5 py-4 border-b border-slate-100">
            <h2 class="text-xs font-semibold text-slate-500 uppercase tracking-wide">
              Payout Ledger
            </h2>
          </div>

          <div :if={@ledger_entries == []} class="p-12 text-center">
            <p class="text-sm font-medium text-slate-500">No ledger entries yet</p>
          </div>

          <table :if={@ledger_entries != []} class="w-full">
            <thead class="bg-slate-50 border-b border-slate-200">
              <tr>
                <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                  Amount Owed
                </th>
                <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                  Status
                </th>
                <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                  Paid At
                </th>
                <th class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr :for={entry <- @ledger_entries} class="hover:bg-slate-50/50 transition-colors">
                <td class="px-6 py-4 text-sm font-mono text-slate-800">
                  {format_price(entry.amount_owed, "GHS")}
                </td>
                <td class="px-6 py-4">
                  <span class={[
                    "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold",
                    if(entry.status == :paid,
                      do: "bg-success-soft text-success",
                      else: "bg-warning-soft text-warning"
                    )
                  ]}>
                    {if entry.status == :paid, do: "Paid", else: "Owed"}
                  </span>
                </td>
                <td class="px-6 py-4 text-sm text-slate-600">
                  {format_datetime(entry.paid_at)}
                </td>
                <td class="px-6 py-4 text-right">
                  <.admin_button
                    :if={entry.status == :owed}
                    size={:sm}
                    phx-click="mark_paid"
                    phx-value-id={entry.id}
                  >
                    <.icon name="hero-check" class="size-3.5" /> Mark paid
                  </.admin_button>
                </td>
              </tr>
            </tbody>
          </table>
        </.admin_card>
      <% end %>
    </div>
    """
  end
end
