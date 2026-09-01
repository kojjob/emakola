defmodule EmakolaWeb.Admin.DeliveryLive.Index do
  @moduledoc """
  Manages delivery zones for a store. Lists zones with fees, estimated days,
  active status. Supports add, edit, delete and Ghana default presets.
  """
  use EmakolaWeb, :live_view

  import EmakolaWeb.Admin.DeliveryLive.MetricsComponents

  alias Emakola.Shipping.DeliveryMetrics
  alias EmakolaWeb.Helpers.Currency

  @ghana_defaults [
    %{name: "Greater Accra", fee: 1500, estimated_days: 1},
    %{name: "Kumasi/Ashanti", fee: 2500, estimated_days: 2},
    %{name: "Other Regions", fee: 3500, estimated_days: 4}
  ]

  @impl true
  def mount(_params, _session, socket) do
    store = socket.assigns.current_store

    socket =
      socket
      |> assign(
        page_title: "Delivery Zones",
        active_nav: :delivery,
        store: store,
        zones: [],
        metrics: nil,
        editing_zone: nil,
        prefill_name: nil,
        show_form: false
      )
      |> load_zones()

    {:ok, socket}
  end

  # The "Add zone for Volta" button on the unmatched row seeds the name.
  @impl true
  def handle_event("show_form", params, socket) do
    {:noreply,
     assign(socket, show_form: true, editing_zone: nil, prefill_name: Map.get(params, "name"))}
  end

  @impl true
  def handle_event("hide_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, editing_zone: nil)}
  end

  @impl true
  def handle_event("save_zone", %{"zone" => params}, socket) do
    store = socket.assigns.store
    fee_pesewas = parse_fee(params["fee"])
    estimated_days = parse_int(params["estimated_days"], 1)

    zone_params = %{
      store_id: store.id,
      name: params["name"],
      fee: fee_pesewas,
      estimated_days: estimated_days,
      free_above_pesewas: parse_optional_fee(params["free_above"]),
      per_kg_fee_pesewas: parse_optional_fee(params["per_kg_fee"])
    }

    case socket.assigns.editing_zone do
      nil ->
        case Emakola.Shipping.create_delivery_zone(zone_params, authorize?: false) do
          {:ok, _zone} ->
            {:noreply,
             socket
             |> assign(show_form: false)
             |> load_zones()
             |> put_flash(:info, "Delivery zone added")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not add zone. Name may already exist.")}
        end

      zone ->
        update_params = Map.drop(zone_params, [:store_id])

        case Emakola.Shipping.update_delivery_zone(zone, update_params, authorize?: false) do
          {:ok, _zone} ->
            {:noreply,
             socket
             |> assign(show_form: false, editing_zone: nil)
             |> load_zones()
             |> put_flash(:info, "Delivery zone updated")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Could not update zone")}
        end
    end
  end

  @impl true
  def handle_event("edit_zone", %{"id" => id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(&1.id == id))

    if zone do
      {:noreply, assign(socket, editing_zone: zone, show_form: true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_zone", %{"id" => id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(&1.id == id))

    if zone do
      case Emakola.Shipping.update_delivery_zone(zone, %{active: !zone.active}, authorize?: false) do
        {:ok, _} -> {:noreply, load_zones(socket)}
        {:error, _} -> {:noreply, put_flash(socket, :error, "Could not update zone")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_zone", %{"id" => id}, socket) do
    zone = Enum.find(socket.assigns.zones, &(&1.id == id))

    if zone do
      case Emakola.Shipping.destroy_delivery_zone(zone, authorize?: false) do
        :ok ->
          {:noreply,
           socket
           |> load_zones()
           |> put_flash(:info, "Zone deleted")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete zone")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_defaults", _params, socket) do
    store = socket.assigns.store

    Enum.each(@ghana_defaults, fn zone_attrs ->
      params = Map.put(zone_attrs, :store_id, store.id)
      Emakola.Shipping.create_delivery_zone(params, authorize?: false)
    end)

    {:noreply,
     socket
     |> load_zones()
     |> put_flash(:info, "Ghana default zones added")}
  end

  # -- Private --

  defp load_zones(socket) do
    store = socket.assigns.store

    if store do
      zones = Emakola.Shipping.list_delivery_zones!(store.id, authorize?: false)
      assign(socket, zones: zones, metrics: DeliveryMetrics.for_store(store.id, zones))
    else
      assign(socket, zones: [], metrics: nil)
    end
  end

  defp parse_fee(fee_str) when is_binary(fee_str) do
    # Money.parse_price rejects negatives and trailing garbage Float.parse let
    # through — a "-5" fee would have SUBTRACTED from the order total.
    case Emakola.Money.parse_price(fee_str) do
      {:ok, pesewas} -> pesewas
      _zero_skip_or_error -> 0
    end
  end

  defp parse_fee(fee) when is_integer(fee), do: fee
  defp parse_fee(_), do: 0

  # Optional GHS inputs: blank/invalid means "not configured" (nil), keeping
  # the zone on flat per-zone pricing.
  defp parse_optional_fee(fee_str) when is_binary(fee_str) do
    case Emakola.Money.parse_price(fee_str) do
      {:ok, pesewas} -> pesewas
      :zero -> 0
      _skip_or_error -> nil
    end
  end

  defp parse_optional_fee(fee) when is_integer(fee), do: fee
  defp parse_optional_fee(_), do: nil

  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default

  defp format_fee(pesewas) when is_integer(pesewas) do
    cedis = pesewas / 100
    :erlang.float_to_binary(cedis, decimals: 2)
  end

  defp format_fee(_), do: "0.00"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <%!-- Header --%>
      <.link
        navigate={~p"/admin/settings"}
        class="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-500 hover:text-slate-700"
      >
        <.icon name="hero-arrow-left" class="size-4" /> Settings
      </.link>

      <.admin_page_header
        icon="hero-truck"
        title="Delivery Zones"
        subtitle="Where you deliver, and what it costs"
      >
        <div class="flex gap-2">
          <button
            :if={@zones == []}
            phx-click="add_defaults"
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
          >
            <.icon name="hero-map-pin" class="size-4" /> Add Ghana Defaults
          </button>
          <button
            phx-click="show_form"
            class="inline-flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
          >
            <.icon name="hero-plus" class="size-4" /> Add Zone
          </button>
        </div>
      </.admin_page_header>

      <.metric_tiles :if={@metrics} metrics={@metrics} zones={@zones} />

      <%!-- Add/Edit form --%>
      <div
        :if={@show_form}
        class="bg-white rounded-2xl shadow-sm p-6"
      >
        <h3 class="text-base font-bold text-slate-900 mb-5">
          {if @editing_zone, do: "Edit Zone", else: "New Delivery Zone"}
        </h3>
        <.form for={%{}} as={:zone} id="new-zone-form" phx-submit="save_zone">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Zone Name</label>
              <input
                type="text"
                name="zone[name]"
                value={(@editing_zone && @editing_zone.name) || @prefill_name}
                placeholder="e.g. Greater Accra"
                required
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Fee (GH&#8373;)
              </label>
              <input
                type="number"
                name="zone[fee]"
                value={@editing_zone && format_fee(@editing_zone.fee)}
                placeholder="15.00"
                step="0.01"
                min="0"
                required
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">Est. Days</label>
              <input
                type="number"
                name="zone[estimated_days]"
                value={(@editing_zone && @editing_zone.estimated_days) || 1}
                min="1"
                required
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Free above (GH&#8373;)
              </label>
              <input
                type="number"
                name="zone[free_above]"
                value={
                  @editing_zone && @editing_zone.free_above_pesewas &&
                    format_fee(@editing_zone.free_above_pesewas)
                }
                placeholder="Optional — order subtotal for free delivery"
                step="0.01"
                min="0"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 mb-1.5">
                Per kg fee (GH&#8373;)
              </label>
              <input
                type="number"
                name="zone[per_kg_fee]"
                value={
                  @editing_zone && @editing_zone.per_kg_fee_pesewas &&
                    format_fee(@editing_zone.per_kg_fee_pesewas)
                }
                placeholder="Optional — added per started kg"
                step="0.01"
                min="0"
                class="w-full px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm text-slate-800 focus:outline-none focus:ring-2 focus:ring-emerald-500/30 focus:border-emerald-500 transition-all"
              />
            </div>
          </div>
          <div class="flex justify-end gap-2 mt-4">
            <button
              type="button"
              phx-click="hide_form"
              class="px-4 py-2.5 bg-white border border-slate-200 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 transition-colors cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              class="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold transition-colors cursor-pointer"
            >
              <.icon name="hero-check" class="size-4" />
              {if @editing_zone, do: "Update Zone", else: "Add Zone"}
            </button>
          </div>
        </.form>
      </div>

      <%!-- Zones list --%>
      <div class="bg-white rounded-2xl shadow-sm overflow-hidden">
        <div :if={@zones == []} class="p-12 text-center">
          <.icon name="hero-truck" class="size-12 text-slate-300 mx-auto mb-4" />
          <p class="text-sm font-medium text-slate-500">No delivery zones yet</p>
          <p class="text-xs text-slate-400 mt-1">
            Add zones to configure delivery fees for different areas
          </p>
        </div>

        <div :if={@zones != []} class="flex items-center gap-2 px-6 pt-5 pb-1">
          <h3 class="text-base font-bold text-slate-900">Your zones</h3>
          <span class="ml-auto text-xs text-slate-500">Orders and fees are the last 30 days</span>
        </div>
        <table :if={@zones != []} class="w-full">
          <thead class="bg-slate-50 border-b border-slate-200">
            <tr>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Zone
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Fee
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Promise
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Free above
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3 w-56">
                Orders
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Fees
              </th>
              <th class="text-left text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                On
              </th>
              <th class="text-right text-xs font-semibold text-slate-500 uppercase tracking-wide px-6 py-3">
                Actions
              </th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              :for={zone <- @zones}
              class={[
                "hover:bg-slate-50/50 transition-colors",
                !zone.active && "bg-slate-50/60"
              ]}
            >
              <td class="px-6 py-4">
                <span class={[
                  "text-sm font-semibold",
                  if(zone.active, do: "text-slate-900", else: "text-slate-500")
                ]}>
                  {zone.name}
                </span>
                <p :if={!zone.active} class="text-[11.5px] font-semibold text-amber-700 mt-0.5">
                  Paused · buyers here pay the default fee
                </p>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm font-semibold text-slate-900 tabular-nums">
                  {Currency.format_price(zone.fee)}
                </span>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm text-slate-600">
                  {zone.estimated_days} {if zone.estimated_days == 1, do: "day", else: "days"}
                </span>
              </td>
              <td class="px-6 py-4">
                <span class="text-sm text-slate-600 tabular-nums">
                  {if zone.free_above_pesewas,
                    do: Currency.format_price(zone.free_above_pesewas),
                    else: "—"}
                </span>
              </td>
              <td class="px-6 py-4">
                <.share_bar
                  id={"zone-orders-#{zone.id}"}
                  count={zone_metric(@metrics, zone, :orders)}
                  total={(@metrics && @metrics.total_orders) || 0}
                  muted={!zone.active}
                />
              </td>
              <td class="px-6 py-4">
                <span
                  id={"zone-fees-#{zone.id}"}
                  class={[
                    "text-sm font-semibold tabular-nums",
                    if(zone.active, do: "text-emerald-700", else: "text-slate-500")
                  ]}
                >
                  {Currency.format_price(zone_metric(@metrics, zone, :fees))}
                </span>
              </td>
              <td class="px-6 py-4">
                <button
                  phx-click="toggle_zone"
                  phx-value-id={zone.id}
                  class={[
                    "relative inline-flex h-6 w-11 items-center rounded-full transition-colors cursor-pointer",
                    if(zone.active, do: "bg-emerald-600", else: "bg-slate-300")
                  ]}
                  role="switch"
                  aria-checked={to_string(zone.active)}
                >
                  <span class={[
                    "inline-block h-5 w-5 transform rounded-full bg-white shadow-sm transition-transform",
                    if(zone.active, do: "translate-x-5", else: "translate-x-0.5")
                  ]} />
                </button>
              </td>
              <td class="px-6 py-4 text-right">
                <div class="flex items-center justify-end gap-2">
                  <button
                    phx-click="edit_zone"
                    phx-value-id={zone.id}
                    class="p-2 rounded-lg hover:bg-slate-100 transition-colors cursor-pointer text-slate-400 hover:text-slate-600"
                    title="Edit"
                  >
                    <.icon name="hero-pencil-square" class="size-4" />
                  </button>
                  <button
                    phx-click="delete_zone"
                    phx-value-id={zone.id}
                    data-confirm="Delete this delivery zone?"
                    class="p-2 rounded-lg hover:bg-red-50 transition-colors cursor-pointer text-slate-400 hover:text-red-500"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="size-4" />
                  </button>
                </div>
              </td>
            </tr>
            <.unmatched_row
              :if={@metrics}
              unmatched={@metrics.unmatched}
              total_orders={@metrics.total_orders}
            />
          </tbody>
        </table>
      </div>

      <div :if={@metrics} class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        <.orders_by_zone metrics={@metrics} zones={@zones} />
        <.buyer_costs metrics={@metrics} zones={@zones} />
      </div>
    </div>
    """
  end

  defp zone_metric(nil, _zone, _key), do: 0

  defp zone_metric(metrics, zone, key),
    do: metrics.per_zone |> Map.get(zone.id, %{}) |> Map.get(key, 0)
end
