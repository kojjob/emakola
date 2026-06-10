defmodule EmakolaWeb.Admin.SupplierLive.Index do
  @moduledoc """
  Manages dropship suppliers for a store. Lists suppliers with contacts,
  active status and outstanding payout balance. Supports inline add/edit and
  an active/inactive toggle (suppliers are never hard-deleted).
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Suppliers",
        active_nav: :settings,
        store: store,
        suppliers: [],
        editing_supplier: nil,
        show_form: false
      )
      |> load_suppliers()

    {:ok, socket}
  end

  @impl true
  def handle_event("show_form", _params, socket) do
    {:noreply, assign(socket, show_form: true, editing_supplier: nil)}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_supplier: nil)}
  end

  @impl true
  def handle_event("save_supplier", %{"supplier" => params}, socket) do
    store = socket.assigns.store

    attrs = %{
      name: params["name"],
      contact_phone: blank_to_nil(params["contact_phone"]),
      whatsapp_number: blank_to_nil(params["whatsapp_number"]),
      contact_email: blank_to_nil(params["contact_email"]),
      payment_details: payment_details(params["payment_info"]),
      notes: blank_to_nil(params["notes"])
    }

    case socket.assigns.editing_supplier do
      nil ->
        case Emakola.Suppliers.create_supplier(Map.put(attrs, :store_id, store.id),
               authorize?: false
             ) do
          {:ok, _supplier} ->
            {:noreply,
             socket
             |> assign(show_form: false)
             |> load_suppliers()
             |> put_flash(:info, "Supplier added")}

          {:error, _} ->
            {:noreply,
             put_flash(socket, :error, "Could not add supplier. Name may already exist.")}
        end

      supplier ->
        case supplier
             |> Ash.Changeset.for_update(:update, attrs)
             |> Ash.update(authorize?: false) do
          {:ok, _supplier} ->
            {:noreply,
             socket
             |> assign(show_form: false, editing_supplier: nil)
             |> load_suppliers()
             |> put_flash(:info, "Supplier updated")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not update supplier")}
        end
    end
  end

  @impl true
  def handle_event("edit_supplier", %{"id" => id}, socket) do
    supplier = Enum.find(socket.assigns.suppliers, &(&1.id == id))

    if supplier do
      {:noreply, assign(socket, editing_supplier: supplier, show_form: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_active", %{"id" => id}, socket) do
    supplier = Enum.find(socket.assigns.suppliers, &(&1.id == id))

    if supplier do
      case supplier
           |> Ash.Changeset.for_update(:update, %{active: !supplier.active})
           |> Ash.update(authorize?: false) do
        {:ok, _} -> {:noreply, load_suppliers(socket)}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update supplier")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Private ──

  defp load_suppliers(socket) do
    store = socket.assigns.store

    if store do
      {:ok, suppliers} =
        Emakola.Suppliers.Supplier
        |> Ash.Query.filter(store_id == ^store.id)
        |> Ash.Query.load(:outstanding_balance)
        |> Ash.Query.sort(:name)
        |> Ash.read(authorize?: false)

      assign(socket, suppliers: suppliers)
    else
      assign(socket, suppliers: [])
    end
  end

  defp payment_details(info) do
    case blank_to_nil(info) do
      nil -> %{}
      value -> %{"info" => value}
    end
  end

  defp payment_info(%{payment_details: %{"info" => info}}), do: info
  defp payment_info(_), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%!-- Header --%>
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div class="flex items-center gap-2 mb-1">
            <.link navigate={~p"/admin/settings"} class="text-slate-400 hover:text-slate-600">
              <.icon name="hero-arrow-left" class="size-4" />
            </.link>
            <h1 class="text-2xl sm:text-3xl font-bold text-slate-900">Suppliers</h1>
          </div>
          <p class="text-sm text-slate-500">Manage dropship suppliers and track what you owe them</p>
        </div>
        <.admin_button phx-click="show_form">
          <.icon name="hero-plus" class="size-4" /> Add Supplier
        </.admin_button>
      </div>

      <%!-- Add/Edit form --%>
      <.admin_card :if={@show_form}>
        <h3 class="text-base font-bold text-slate-900 mb-5">
          {if @editing_supplier, do: "Edit Supplier", else: "New Supplier"}
        </h3>
        <.form for={%{}} as={:supplier} id="supplier-form" phx-submit="save_supplier">
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Name</label>
              <input
                type="text"
                name="supplier[name]"
                value={@editing_supplier && @editing_supplier.name}
                placeholder="e.g. Accra Wholesale Ltd"
                required
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Contact Phone</label>
              <input
                type="text"
                name="supplier[contact_phone]"
                value={@editing_supplier && @editing_supplier.contact_phone}
                placeholder="+233 24 000 0000"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">WhatsApp Number</label>
              <input
                type="text"
                name="supplier[whatsapp_number]"
                value={@editing_supplier && @editing_supplier.whatsapp_number}
                placeholder="+233 24 000 0000"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Contact Email</label>
              <input
                type="email"
                name="supplier[contact_email]"
                value={@editing_supplier && @editing_supplier.contact_email}
                placeholder="supplier@example.com"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                MoMo / Payment Info
              </label>
              <input
                type="text"
                name="supplier[payment_info]"
                value={@editing_supplier && payment_info(@editing_supplier)}
                placeholder="e.g. MTN MoMo 024 000 0000"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Notes</label>
              <input
                type="text"
                name="supplier[notes]"
                value={@editing_supplier && @editing_supplier.notes}
                placeholder="Lead times, minimums, etc."
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-control text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
          </div>
          <div class="flex justify-end gap-2 mt-4">
            <.admin_button variant={:secondary} phx-click="hide_form">
              Cancel
            </.admin_button>
            <.admin_button type="submit">
              <.icon name="hero-check" class="size-4" />
              {if @editing_supplier, do: "Update Supplier", else: "Add Supplier"}
            </.admin_button>
          </div>
        </.form>
      </.admin_card>

      <%!-- Suppliers list --%>
      <.admin_card padding={:none} class="overflow-hidden">
        <div :if={@suppliers == []} class="p-12 text-center">
          <.icon name="hero-truck" class="size-12 text-slate-300 mx-auto mb-4" />
          <p class="text-sm font-medium text-slate-500">No suppliers yet</p>
          <p class="text-xs text-slate-400 mt-1">
            Add suppliers to source products via dropshipping
          </p>
        </div>

        <table :if={@suppliers != []} class="w-full">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Supplier
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Contact
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Owed
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Status
              </th>
              <th class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr :for={supplier <- @suppliers} class="hover:bg-slate-50/50 transition-colors">
              <td class="px-6 py-4">
                <.link
                  navigate={~p"/admin/suppliers/#{supplier.id}"}
                  class="text-sm font-medium text-slate-900 hover:text-primary"
                >
                  {supplier.name}
                </.link>
              </td>
              <td class="px-6 py-4">
                <div class="text-sm text-slate-600">
                  <p :if={supplier.contact_phone}>{supplier.contact_phone}</p>
                  <p :if={supplier.whatsapp_number} class="text-xs text-slate-400">
                    WhatsApp: {supplier.whatsapp_number}
                  </p>
                  <p :if={supplier.contact_email} class="text-xs text-slate-400">
                    {supplier.contact_email}
                  </p>
                </div>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm font-mono text-slate-700">
                  {format_price(supplier.outstanding_balance || 0, "GHS")}
                </span>
              </td>
              <td class="px-6 py-4">
                <button
                  phx-click="toggle_active"
                  phx-value-id={supplier.id}
                  class={[
                    "relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer",
                    if(supplier.active, do: "bg-primary", else: "bg-slate-300")
                  ]}
                  role="switch"
                  aria-checked={to_string(supplier.active)}
                >
                  <span class={[
                    "inline-block h-5 w-5 transform rounded-full bg-white shadow-sm transition-transform",
                    if(supplier.active, do: "translate-x-5", else: "translate-x-0.5")
                  ]} />
                </button>
              </td>
              <td class="px-6 py-4 text-right">
                <div class="flex items-center justify-end gap-2">
                  <.link
                    navigate={~p"/admin/suppliers/#{supplier.id}"}
                    class="p-2 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer text-slate-400 hover:text-slate-600"
                    title="View ledger"
                  >
                    <.icon name="hero-banknotes" class="size-4" />
                  </.link>
                  <button
                    phx-click="edit_supplier"
                    phx-value-id={supplier.id}
                    class="p-2 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer text-slate-400 hover:text-slate-600"
                    title="Edit"
                  >
                    <.icon name="hero-pencil-square" class="size-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </.admin_card>
    </div>
    """
  end
end
