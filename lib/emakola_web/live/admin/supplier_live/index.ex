defmodule EmakolaWeb.Admin.SupplierLive.Index do
  @moduledoc """
  Manages dropship suppliers for a store. Shows a tile grid (avatar, owed
  badge, tap-to-call/WhatsApp) designed for low-literacy merchants, with a
  slide-over add/edit form. Suppliers are never hard-deleted — the active
  toggle lives in the edit slide-over.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Helpers.Currency, only: [format_price: 2]

  @avatar_colors ~w(bg-sky-500 bg-amber-500 bg-violet-500 bg-rose-500
                    bg-primary bg-indigo-500 bg-orange-500 bg-teal-500)

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Suppliers",
        active_nav: :suppliers,
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
        case Emakola.Suppliers.update_supplier(supplier, attrs, authorize?: false) do
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
      case Emakola.Suppliers.update_supplier(supplier, %{active: !supplier.active},
             authorize?: false
           ) do
        {:ok, updated} ->
          socket =
            if socket.assigns.editing_supplier do
              assign(socket, editing_supplier: updated)
            else
              socket
            end

          {:noreply, load_suppliers(socket)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not update supplier")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Private ──

  defp load_suppliers(socket) do
    store = socket.assigns.store

    if store do
      suppliers = Emakola.Suppliers.list_suppliers_by_store!(store.id, authorize?: false)
      suppliers = Ash.load!(suppliers, :outstanding_balance, authorize?: false)
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

  defp avatar_color(name) do
    Enum.at(@avatar_colors, :erlang.phash2(name || "", length(@avatar_colors)))
  end

  defp initial(name) do
    case name |> to_string() |> String.trim() |> String.first() do
      nil -> "?"
      letter -> String.upcase(letter)
    end
  end

  defp wa_link(number), do: "https://wa.me/" <> String.replace(number, ~r/\D/, "")

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
        <.admin_button id="add-supplier-btn" phx-click="show_form">
          <.icon name="hero-plus" class="size-4" /> Add Supplier
        </.admin_button>
      </div>

      <%!-- Empty state --%>
      <div
        :if={@suppliers == []}
        class="bg-white border border-slate-200 rounded-card p-12 text-center"
      >
        <.icon name="hero-truck" class="size-12 text-slate-300 mx-auto mb-4" />
        <p class="text-sm font-medium text-slate-500">No suppliers yet</p>
        <p class="text-xs text-slate-400 mt-1">
          Add suppliers to source products via dropshipping
        </p>
      </div>

      <%!-- Tile grid --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div
          :for={supplier <- @suppliers}
          class={[
            "relative bg-white border border-slate-200 rounded-card p-4 text-center shadow-sm",
            "hover:shadow-md hover:border-slate-300 transition-all",
            !supplier.active && "opacity-60"
          ]}
        >
          <span
            :if={!supplier.active}
            class="absolute top-2.5 left-2.5 text-[10px] font-bold uppercase tracking-wide
                   bg-slate-100 text-slate-500 rounded-full px-2 py-0.5"
          >
            Inactive
          </span>
          <button
            phx-click="edit_supplier"
            phx-value-id={supplier.id}
            class="absolute top-2 right-2 p-2 rounded-lg text-slate-300 hover:text-slate-600
                   hover:bg-slate-100 transition-colors"
            aria-label={"Edit #{supplier.name}"}
          >
            <.icon name="hero-pencil-square" class="size-4" />
          </button>

          <.link navigate={~p"/admin/suppliers/#{supplier.id}"} class="block group">
            <div class={[
              "w-12 h-12 rounded-full text-white flex items-center justify-center",
              "font-bold text-lg mx-auto mb-2",
              avatar_color(supplier.name)
            ]}>
              {initial(supplier.name)}
            </div>
            <p class="font-semibold text-sm text-slate-900 truncate group-hover:text-primary">
              {supplier.name}
            </p>
          </.link>

          <div class="my-2">
            <span
              :if={(supplier.outstanding_balance || 0) > 0}
              class="inline-block bg-red-50 text-red-600 font-bold text-sm rounded-full px-3 py-1"
            >
              {format_price(supplier.outstanding_balance, "GHS")}
            </span>
            <span
              :if={(supplier.outstanding_balance || 0) == 0}
              class="inline-flex items-center gap-1 bg-green-50 text-green-700 font-bold
                     text-sm rounded-full px-3 py-1"
            >
              <.icon name="hero-check" class="size-3.5" /> Paid
            </span>
          </div>

          <div class="flex justify-center gap-2">
            <a
              :if={supplier.contact_phone}
              href={"tel:#{supplier.contact_phone}"}
              class="w-9 h-9 rounded-full bg-emerald-50 text-emerald-600 hover:bg-emerald-100
                     flex items-center justify-center transition-colors"
              aria-label={"Call #{supplier.name}"}
            >
              <.icon name="hero-phone" class="size-4" />
            </a>
            <a
              :if={supplier.whatsapp_number}
              href={wa_link(supplier.whatsapp_number)}
              target="_blank"
              rel="noopener"
              class="w-9 h-9 rounded-full bg-green-50 text-green-600 hover:bg-green-100
                     flex items-center justify-center transition-colors"
              aria-label={"WhatsApp #{supplier.name}"}
            >
              <.whatsapp_icon class="size-4" />
            </a>
          </div>
        </div>

        <button
          id="add-supplier-tile"
          phx-click="show_form"
          class="min-h-[150px] border-2 border-dashed border-slate-300 rounded-card
                 flex flex-col items-center justify-center gap-1 text-slate-400
                 hover:text-emerald-600 hover:border-emerald-400 transition-colors"
        >
          <.icon name="hero-plus" class="size-6" />
          <span class="text-sm font-semibold">Add Supplier</span>
        </button>
      </div>

      <%!-- Add/Edit slide-over --%>
      <.modal
        :if={@show_form}
        id="supplier-form-modal"
        title={if @editing_supplier, do: "Edit Supplier", else: "New Supplier"}
        kind={:slide_over}
        show
        on_cancel={JS.push("hide_form")}
      >
        <.form for={%{}} as={:supplier} id="supplier-form" phx-submit="save_supplier">
          <div class="space-y-4">
            <div>
              <label for="sf_name" class="block text-sm font-medium text-slate-700 mb-1.5">
                Name <span class="text-red-500">*</span>
              </label>
              <input
                type="text"
                id="sf_name"
                name="supplier[name]"
                value={@editing_supplier && @editing_supplier.name}
                placeholder="e.g. Accra Wholesale Ltd"
                required
                class="w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-base
                       text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                       focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label for="sf_phone" class="block text-sm font-medium text-slate-700 mb-1.5">
                Contact Phone
              </label>
              <input
                type="tel"
                id="sf_phone"
                name="supplier[contact_phone]"
                value={@editing_supplier && @editing_supplier.contact_phone}
                placeholder="+233 24 000 0000"
                class="w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-base
                       text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                       focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label for="sf_whatsapp" class="block text-sm font-medium text-slate-700 mb-1.5">
                WhatsApp Number
              </label>
              <input
                type="tel"
                id="sf_whatsapp"
                name="supplier[whatsapp_number]"
                value={@editing_supplier && @editing_supplier.whatsapp_number}
                placeholder="+233 24 000 0000"
                class="w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-base
                       text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                       focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label for="sf_email" class="block text-sm font-medium text-slate-700 mb-1.5">
                Contact Email
              </label>
              <input
                type="email"
                id="sf_email"
                name="supplier[contact_email]"
                value={@editing_supplier && @editing_supplier.contact_email}
                placeholder="supplier@example.com"
                class="w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-base
                       text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                       focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label for="sf_payment" class="block text-sm font-medium text-slate-700 mb-1.5">
                MoMo / Payment Info
              </label>
              <input
                type="text"
                id="sf_payment"
                name="supplier[payment_info]"
                value={@editing_supplier && payment_info(@editing_supplier)}
                placeholder="e.g. MTN MoMo 024 000 0000"
                class="w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-base
                       text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                       focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label for="sf_notes" class="block text-sm font-medium text-slate-700 mb-1.5">
                Notes
              </label>
              <input
                type="text"
                id="sf_notes"
                name="supplier[notes]"
                value={@editing_supplier && @editing_supplier.notes}
                placeholder="Lead times, minimums, etc."
                class="w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-base
                       text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30
                       focus:border-emerald-500 transition-all"
              />
            </div>

            <div
              :if={@editing_supplier}
              class="flex items-center justify-between border-t border-slate-200 pt-4"
            >
              <div>
                <p class="text-sm font-medium text-slate-700">Active</p>
                <p class="text-xs text-slate-400">Inactive suppliers are hidden from dropshipping</p>
              </div>
              <button
                type="button"
                phx-click="toggle_active"
                phx-value-id={@editing_supplier.id}
                class={[
                  "relative inline-flex h-6 w-11 items-center rounded-full transition-colors",
                  if(@editing_supplier.active, do: "bg-primary", else: "bg-slate-300")
                ]}
                role="switch"
                aria-checked={to_string(@editing_supplier.active)}
              >
                <span class={[
                  "inline-block h-5 w-5 transform rounded-full bg-white shadow-sm transition-transform",
                  if(@editing_supplier.active, do: "translate-x-5", else: "translate-x-0.5")
                ]} />
              </button>
            </div>
          </div>
        </.form>
        <:footer>
          <div class="flex justify-end gap-3">
            <.admin_button
              variant={:secondary}
              phx-click={JS.exec("data-cancel", to: "#supplier-form-modal")}
            >
              Cancel
            </.admin_button>
            <.admin_button type="submit" form="supplier-form">
              <.icon name="hero-check" class="size-4" />
              {if @editing_supplier, do: "Update Supplier", else: "Add Supplier"}
            </.admin_button>
          </div>
        </:footer>
      </.modal>
    </div>
    """
  end

  attr :class, :string, default: "size-4"

  defp whatsapp_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      <path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347Z" />
      <path d="M12.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 0 0 5.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893A11.821 11.821 0 0 0 20.464 3.48 11.815 11.815 0 0 0 12.05 0Zm0 21.785h-.004a9.87 9.87 0 0 1-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 0 1-1.51-5.26C2.117 6.443 6.552 2.009 12.004 2.009c2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 0 1 2.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884Z" />
    </svg>
    """
  end
end
