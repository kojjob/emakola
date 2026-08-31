defmodule EmakolaWeb.InventoryComponents do
  @moduledoc """
  Shared UI components for the inventory management page.

  Provides stock status badges, the multi-location manager card,
  per-location breakdown lines, and the stock transfer modal used by the
  admin inventory dashboard.
  """
  use Phoenix.Component

  import EmakolaWeb.AdminComponents, only: [admin_button: 1, admin_card: 1]
  import EmakolaWeb.CoreComponents, only: [hide_modal: 1, icon: 1, input: 1, modal: 1]

  @doc """
  Renders a color-coded stock status badge.

  - Green "In Stock" when quantity >= 10
  - Amber "Low Stock" when quantity 1-9
  - Red "Out of Stock" with pulse dot when quantity is 0
  - Neutral "Supplier" when the variant does not track its own stock
  """
  attr :quantity, :integer, required: true

  attr :tracked, :boolean,
    default: true,
    doc: """
    `false` for a variant whose stock is somebody else's. A dropship listing
    imported from a supplier carries `track_inventory: false` and a zero
    quantity on purpose, and `Variant.in_stock?/2` still sells it — so the
    red pill said sold out about a listing that was selling.
    """

  def stock_status_badge(assigns) do
    {label, color_classes, show_pulse} = stock_status(assigns.quantity, assigns.tracked)
    assigns = assign(assigns, label: label, color_classes: color_classes, show_pulse: show_pulse)

    ~H"""
    <span class={[
      "inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold",
      @color_classes
    ]}>
      <span
        :if={@show_pulse}
        class="relative flex h-2 w-2"
      >
        <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-red-400 opacity-75">
        </span>
        <span class="relative inline-flex rounded-full h-2 w-2 bg-red-500"></span>
      </span>
      {@label}
    </span>
    """
  end

  @doc """
  Renders the locations manager card — every stock location with its
  Default/Inactive pills, per-location total, and management actions
  (rename, set default, deactivate). Events are handled by the parent
  LiveView.
  """
  attr :locations, :list, required: true
  attr :totals, :map, required: true
  attr :renaming_id, :string, default: nil
  attr :show_form, :boolean, default: false
  attr :location_form, Phoenix.HTML.Form, required: true
  attr :rename_location_form, Phoenix.HTML.Form, required: true

  def locations_card(assigns) do
    ~H"""
    <.admin_card padding={:none} class="overflow-hidden">
      <div class="flex items-center justify-between gap-3 px-4 sm:px-6 py-4 border-b border-slate-100">
        <div>
          <h2 class="text-sm font-semibold text-slate-800">Locations</h2>
          <p class="text-xs text-slate-500 mt-0.5">
            Where your stock lives — shops, stalls, warehouses
          </p>
        </div>
        <.admin_button variant={:secondary} size={:sm} phx-click="toggle_location_form">
          <.icon name="hero-plus" class="w-3.5 h-3.5" /> Add location
        </.admin_button>
      </div>

      <div :if={@show_form} class="px-4 sm:px-6 py-3 border-b border-slate-100 bg-slate-50/50">
        <.form
          for={@location_form}
          id="add-location-form"
          phx-submit="create_location"
          class="flex items-center gap-2"
        >
          <div class="flex-1">
            <.input
              field={@location_form[:name]}
              type="text"
              required
              maxlength="120"
              placeholder="e.g. Market Stall, Warehouse"
              class="w-full px-3 py-2 text-sm border border-slate-200 rounded-lg bg-white focus:outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-300"
              autofocus
            />
          </div>
          <.admin_button type="submit" size={:sm}>Add</.admin_button>
          <.admin_button variant={:secondary} size={:sm} phx-click="toggle_location_form">
            Cancel
          </.admin_button>
        </.form>
      </div>

      <ul class="divide-y divide-slate-100">
        <li
          :for={location <- @locations}
          class="flex flex-wrap items-center gap-x-3 gap-y-2 px-4 sm:px-6 py-3"
        >
          <%= if @renaming_id == location.id do %>
            <.form
              for={@rename_location_form}
              id="rename-location-form"
              phx-submit="rename_location"
              class="flex items-center gap-2"
            >
              <.input field={@rename_location_form[:location_id]} type="hidden" />
              <div class="w-44">
                <.input
                  field={@rename_location_form[:name]}
                  type="text"
                  required
                  maxlength="120"
                  class="w-full px-2 py-1 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                  autofocus
                />
              </div>
              <button type="submit" class="text-primary hover:text-primary-hover" title="Save">
                <.icon name="hero-check" class="w-4 h-4" />
              </button>
              <button
                type="button"
                phx-click="cancel_rename_location"
                class="text-slate-400 hover:text-slate-600"
                title="Cancel"
              >
                <.icon name="hero-x-mark" class="w-4 h-4" />
              </button>
            </.form>
          <% else %>
            <span class="text-sm font-medium text-slate-800">{location.name}</span>
          <% end %>

          <span
            :if={location.default}
            class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700"
          >
            Default
          </span>
          <span
            :if={!location.active}
            class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-500"
          >
            Inactive
          </span>

          <div class="ml-auto flex items-center gap-3">
            <span class="font-mono text-sm font-semibold text-slate-700">
              {Map.get(@totals, location.id, 0)}
              <span class="font-sans text-xs font-normal text-slate-400">in stock</span>
            </span>
            <div :if={location.active} class="flex items-center gap-2">
              <button
                phx-click="start_rename_location"
                phx-value-id={location.id}
                class="text-xs font-medium text-slate-500 hover:text-slate-700"
              >
                Rename
              </button>
              <button
                :if={!location.default}
                phx-click="set_default_location"
                phx-value-id={location.id}
                class="text-xs font-medium text-slate-500 hover:text-slate-700"
              >
                Make default
              </button>
              <button
                :if={!location.default}
                phx-click="deactivate_location"
                phx-value-id={location.id}
                class="text-xs font-medium text-slate-500 hover:text-red-600"
              >
                Deactivate
              </button>
            </div>
          </div>
        </li>
      </ul>
    </.admin_card>
    """
  end

  @doc """
  Renders the small per-location stock line shown under a variant's total
  when the store has more than one location, e.g. "Main 6 · Stall 4".
  Renders nothing when there are no entries.
  """
  attr :entries, :list, required: true, doc: "list of {location_name, quantity} tuples"

  def location_breakdown(assigns) do
    ~H"""
    <p :if={@entries != []} class="location-breakdown font-mono text-[11px] text-slate-400 mt-0.5">
      {Enum.map_join(@entries, " · ", fn {name, qty} -> "#{name} #{qty}" end)}
    </p>
    """
  end

  @doc """
  Renders the stock transfer modal — move a quantity of the given variant
  between two locations. Submits `save_transfer` to the parent LiveView.
  """
  attr :variant, :map, default: nil
  attr :locations, :list, required: true
  attr :form, Phoenix.HTML.Form, required: true

  def transfer_modal(assigns) do
    active = Enum.filter(assigns.locations, & &1.active)

    assigns = assign(assigns, :active_locations, active)

    ~H"""
    <.modal id="transfer-modal" title="Transfer Stock" size={:md}>
      <.form
        :if={@variant}
        for={@form}
        id="transfer-form"
        phx-submit="save_transfer"
        class="space-y-4"
      >
        <p class="text-sm text-slate-600">
          {variant_title(@variant)}
          <span :if={@variant.sku} class="font-mono text-xs text-slate-400">({@variant.sku})</span>
        </p>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">From</label>
            <.input
              field={@form[:from_location_id]}
              type="select"
              options={Enum.map(@active_locations, &{&1.name, &1.id})}
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>
          <div>
            <label class="block text-sm font-medium text-slate-700 mb-1.5">To</label>
            <.input
              field={@form[:to_location_id]}
              type="select"
              options={Enum.map(@active_locations, &{&1.name, &1.id})}
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>
        </div>
        <div>
          <label class="block text-sm font-medium text-slate-700 mb-1.5">Quantity</label>
          <.input
            field={@form[:quantity]}
            type="number"
            min="1"
            step="1"
            required
            placeholder="0"
            class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
          />
        </div>
        <div class="flex items-center justify-end gap-3 pt-2">
          <.admin_button variant={:secondary} phx-click={hide_modal("transfer-modal")}>
            Cancel
          </.admin_button>
          <.admin_button type="submit" phx-click={hide_modal("transfer-modal")}>
            Transfer
          </.admin_button>
        </div>
      </.form>
    </.modal>
    """
  end

  # ── Helpers ──

  defp variant_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp variant_title(_), do: "Unknown Product"

  defp stock_status(_qty, false), do: {"Supplier", "bg-slate-100 text-slate-600", false}

  defp stock_status(qty, _tracked) when qty >= 10,
    do: {"In Stock", "bg-emerald-50 text-emerald-700", false}

  defp stock_status(qty, _tracked) when qty >= 1,
    do: {"Low Stock", "bg-amber-50 text-amber-700", false}

  defp stock_status(_qty, _tracked), do: {"Out of Stock", "bg-red-50 text-red-700", true}
end
