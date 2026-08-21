defmodule EmakolaWeb.Admin.InventoryLive do
  @moduledoc """
  Inventory management dashboard for the merchant admin.

  Displays stock overview stats (total SKUs, in stock, low stock, out of stock),
  a locations manager (add/rename/set-default/deactivate), a filterable table
  of all variants with inline stock adjustment controls and per-location
  breakdowns, a stock transfer modal, and search by product title or SKU.
  """
  use EmakolaWeb, :live_view

  require Logger

  import EmakolaWeb.InventoryComponents

  @impl true
  def mount(_params, _session, socket) do
    store_id = get_store_id(socket)

    socket =
      socket
      |> assign(
        page_title: "Inventory",
        active_nav: :inventory,
        store_id: store_id,
        status_filter: :all,
        search_query: "",
        search_form: to_form(%{"query" => ""}),
        variants: [],
        stats: %{total: 0, in_stock: 0, low_stock: 0, out_of_stock: 0},
        editing_variant_id: nil,
        edit_stock_value: "",
        edit_location_id: nil,
        stock_form: stock_form(),
        suppliers: [],
        dropship_variant: nil,
        dropship_form: dropship_form(nil),
        locations: [],
        location_totals: %{},
        levels_by_variant: %{},
        susu_reserved_by_variant: %{},
        multi_location?: false,
        show_location_form: false,
        location_form: location_form(),
        renaming_location_id: nil,
        rename_location_form: rename_location_form(),
        transfer_variant: nil,
        transfer_form: transfer_form([])
      )
      |> load_suppliers()
      |> reload_inventory()

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    status_atom =
      case status do
        "all" -> :all
        "in_stock" -> :in_stock
        "low_stock" -> :low_stock
        "out_of_stock" -> :out_of_stock
        _ -> :all
      end

    socket =
      socket
      |> assign(status_filter: status_atom)
      |> apply_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("search_inventory", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(search_query: query, search_form: to_form(%{"query" => query}))
      |> apply_filters()

    {:noreply, socket}
  end

  @impl true
  def handle_event("adjust_stock", %{"id" => variant_id, "delta" => delta_str}, socket) do
    delta = String.to_integer(delta_str)

    # Store scoping: the variant must be in the session-resolved store's
    # list — params are never trusted for tenancy.
    case find_variant(socket.assigns.all_variants, variant_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "Variant not found")}

      variant ->
        # Funnel through the Inventory domain (quick +/- always hits the
        # default location) so the level, the variant total, and the
        # movement ledger stay in sync.
        location = Emakola.Inventory.ensure_default_location!(socket.assigns.store_id)

        case Emakola.Inventory.adjust(variant.id, location.id, delta, :adjustment) do
          {:ok, _} ->
            {:noreply, reload_inventory(socket)}

          {:error, _error} ->
            {:noreply, put_flash(socket, :error, "Could not adjust stock")}
        end
    end
  end

  @impl true
  def handle_event("start_edit", %{"id" => variant_id}, socket) do
    variant = find_variant(socket.assigns.all_variants, variant_id)
    default = Enum.find(socket.assigns.locations, & &1.default)
    default_id = default && default.id

    current_stock =
      if variant && default_id,
        do: Integer.to_string(location_quantity(socket, variant, default_id)),
        else: ""

    {:noreply,
     assign(socket,
       editing_variant_id: variant_id,
       edit_stock_value: current_stock,
       edit_location_id: default_id,
       stock_form: stock_form(variant_id, default_id, current_stock)
     )}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, close_editor(socket)}
  end

  @impl true
  def handle_event("edit_location_changed", %{"location_id" => location_id} = params, socket) do
    if location_id == socket.assigns.edit_location_id do
      stock = params["stock"] || ""

      {:noreply,
       assign(socket,
         edit_stock_value: stock,
         stock_form: stock_form(socket.assigns.editing_variant_id, location_id, stock)
       )}
    else
      # Location switched — re-prefill with that location's current stock.
      variant = find_variant(socket.assigns.all_variants, socket.assigns.editing_variant_id)
      location = find_location(socket.assigns.locations, location_id)

      value =
        if variant && location,
          do: Integer.to_string(location_quantity(socket, variant, location.id)),
          else: ""

      {:noreply,
       assign(socket,
         edit_location_id: location_id,
         edit_stock_value: value,
         stock_form: stock_form(socket.assigns.editing_variant_id, location_id, value)
       )}
    end
  end

  @impl true
  def handle_event(
        "save_stock",
        %{"variant_id" => variant_id, "location_id" => location_id, "stock" => stock_str},
        socket
      ) do
    variant = find_variant(socket.assigns.all_variants, variant_id)
    # Location must belong to this store — validated against the
    # server-loaded list, never the raw param.
    location = find_location(socket.assigns.locations, location_id)

    case Integer.parse(stock_str) do
      {new_stock, _} when new_stock >= 0 ->
        cond do
          is_nil(variant) -> {:noreply, put_flash(socket, :error, "Variant not found")}
          is_nil(location) -> {:noreply, put_flash(socket, :error, "Location not found")}
          true -> save_stock_at_location(socket, variant, location, new_stock)
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Please enter a valid non-negative number")}
    end
  end

  @impl true
  def handle_event("edit_dropship", %{"id" => variant_id}, socket) do
    variant = find_variant(socket.assigns.all_variants, variant_id)

    {:noreply, assign(socket, dropship_variant: variant, dropship_form: dropship_form(variant))}
  end

  @impl true
  def handle_event("cancel_dropship", _params, socket) do
    {:noreply, assign(socket, dropship_variant: nil, dropship_form: dropship_form(nil))}
  end

  @impl true
  def handle_event("save_dropship", %{"variant" => params}, socket) do
    variant = socket.assigns.dropship_variant
    supplier_id = blank_to_nil(params["supplier_id"])
    socket = assign(socket, dropship_form: to_form(params, as: :variant))

    cond do
      is_nil(variant) ->
        {:noreply, put_flash(socket, :error, "Variant not found")}

      not valid_supplier?(socket.assigns.suppliers, supplier_id) ->
        {:noreply, put_flash(socket, :error, "Invalid supplier")}

      true ->
        save_dropship_variant(socket, variant, supplier_id, params)
    end
  end

  # ── Location management ──
  #
  # Every handler passes the session-resolved actor + store into the
  # Inventory context, which enforces store membership — params only
  # ever carry the location id, validated inside the context against
  # the same store.

  @impl true
  def handle_event("toggle_location_form", _params, socket) do
    {:noreply,
     assign(socket,
       show_location_form: !socket.assigns.show_location_form,
       location_form: location_form()
     )}
  end

  @impl true
  def handle_event("create_location", %{"name" => name}, socket) do
    socket = assign(socket, location_form: to_form(%{"name" => name}))

    case Emakola.Inventory.create_location(actor(socket), socket.assigns.store_id, %{name: name}) do
      {:ok, _location} ->
        {:noreply,
         socket
         |> assign(show_location_form: false, location_form: location_form())
         |> put_flash(:info, "Location added")
         |> reload_inventory()}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You don't have access to this store")}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "Could not add location — names must be unique per store")}
    end
  end

  @impl true
  def handle_event("start_rename_location", %{"id" => location_id}, socket) do
    location = find_location(socket.assigns.locations, location_id)

    {:noreply,
     assign(socket,
       renaming_location_id: location_id,
       rename_location_form: rename_location_form(location)
     )}
  end

  @impl true
  def handle_event("cancel_rename_location", _params, socket) do
    {:noreply,
     assign(socket,
       renaming_location_id: nil,
       rename_location_form: rename_location_form()
     )}
  end

  @impl true
  def handle_event("rename_location", %{"location_id" => location_id, "name" => name}, socket) do
    socket =
      assign(socket,
        rename_location_form: to_form(%{"location_id" => location_id, "name" => name})
      )

    case Emakola.Inventory.rename_location(
           actor(socket),
           socket.assigns.store_id,
           location_id,
           name
         ) do
      {:ok, _location} ->
        {:noreply,
         socket
         |> assign(
           renaming_location_id: nil,
           rename_location_form: rename_location_form()
         )
         |> put_flash(:info, "Location renamed")
         |> reload_inventory()}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "Could not rename location — names must be unique per store")}
    end
  end

  @impl true
  def handle_event("set_default_location", %{"id" => location_id}, socket) do
    case Emakola.Inventory.set_default_location(
           actor(socket),
           socket.assigns.store_id,
           location_id
         ) do
      {:ok, _location} ->
        {:noreply, socket |> put_flash(:info, "Default location updated") |> reload_inventory()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not update the default location")}
    end
  end

  @impl true
  def handle_event("deactivate_location", %{"id" => location_id}, socket) do
    case Emakola.Inventory.deactivate_location(
           actor(socket),
           socket.assigns.store_id,
           location_id
         ) do
      {:ok, _location} ->
        {:noreply, socket |> put_flash(:info, "Location deactivated") |> reload_inventory()}

      {:error, :default_location} ->
        {:noreply, put_flash(socket, :error, "The default location can't be deactivated")}

      {:error, :location_holds_stock} ->
        {:noreply,
         put_flash(socket, :error, "Move its stock first — this location still holds stock")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not deactivate location")}
    end
  end

  # ── Stock transfer ──

  @impl true
  def handle_event("open_transfer", %{"id" => variant_id}, socket) do
    variant = find_variant(socket.assigns.all_variants, variant_id)

    {:noreply,
     assign(socket,
       transfer_variant: variant,
       transfer_form: transfer_form(socket.assigns.locations)
     )}
  end

  @impl true
  def handle_event("save_transfer", %{"transfer" => params}, socket) do
    socket = assign(socket, transfer_form: to_form(params, as: :transfer))
    variant = socket.assigns.transfer_variant
    # Locations must belong to this store — validated against the
    # server-loaded list, never the raw params.
    from = find_location(socket.assigns.locations, params["from_location_id"])
    to = find_location(socket.assigns.locations, params["to_location_id"])
    quantity = parse_positive_int(params["quantity"])

    cond do
      is_nil(variant) -> {:noreply, put_flash(socket, :error, "Variant not found")}
      is_nil(from) or is_nil(to) -> {:noreply, put_flash(socket, :error, "Location not found")}
      is_nil(quantity) -> {:noreply, put_flash(socket, :error, "Enter a quantity greater than 0")}
      true -> run_transfer(socket, variant, from, to, quantity)
    end
  end

  defp run_transfer(socket, variant, from, to, quantity) do
    case Emakola.Inventory.transfer(variant.id, from.id, to.id, quantity) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(
           transfer_variant: nil,
           transfer_form: transfer_form(socket.assigns.locations)
         )
         |> put_flash(:info, "Stock transferred")
         |> reload_inventory()}

      {:error, :same_location} ->
        {:noreply, put_flash(socket, :error, "Choose two different locations")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Not enough stock at the source location")}
    end
  end

  defp save_stock_at_location(socket, variant, location, new_stock) do
    delta = new_stock - location_quantity(socket, variant, location.id)

    if delta == 0 do
      {:noreply, close_editor(socket)}
    else
      case Emakola.Inventory.adjust(variant.id, location.id, delta, :adjustment) do
        {:ok, _} -> {:noreply, socket |> close_editor() |> reload_inventory()}
        {:error, _error} -> {:noreply, put_flash(socket, :error, "Could not update stock")}
      end
    end
  end

  defp stock_form(variant_id \\ "", location_id \\ "", stock \\ "") do
    to_form(%{
      "variant_id" => variant_id || "",
      "location_id" => location_id || "",
      "stock" => stock
    })
  end

  defp location_form, do: to_form(%{"name" => ""})

  defp rename_location_form(location \\ nil)

  defp rename_location_form(nil),
    do: to_form(%{"location_id" => "", "name" => ""})

  defp rename_location_form(location) do
    to_form(%{"location_id" => location.id, "name" => location.name})
  end

  defp transfer_form(locations) do
    active_locations = Enum.filter(locations, & &1.active)

    to_form(
      %{
        "from_location_id" =>
          Enum.find_value(active_locations, fn location -> location.default && location.id end) ||
            "",
        "to_location_id" =>
          Enum.find_value(active_locations, fn location -> !location.default && location.id end) ||
            "",
        "quantity" => ""
      },
      as: :transfer
    )
  end

  defp dropship_form(nil) do
    to_form(
      %{"supplier_id" => "", "cost_price" => "", "available" => false},
      as: :variant
    )
  end

  defp dropship_form(variant) do
    to_form(
      %{
        "supplier_id" => variant.supplier_id || "",
        "cost_price" => cost_in_cedis(variant.cost_price),
        "available" => variant.available
      },
      as: :variant
    )
  end

  defp close_editor(socket),
    do:
      assign(socket,
        editing_variant_id: nil,
        edit_stock_value: "",
        edit_location_id: nil,
        stock_form: stock_form()
      )

  defp save_dropship_variant(socket, variant, supplier_id, params) do
    attrs = %{
      supplier_id: supplier_id,
      cost_price: parse_cost(params["cost_price"]),
      available: params["available"] == "true"
    }

    case Emakola.Catalog.update_variant(variant, attrs, authorize?: false) do
      {:ok, _updated} ->
        {:noreply,
         socket
         |> assign(dropship_variant: nil, dropship_form: dropship_form(nil))
         |> load_variants()
         |> put_flash(:info, "Variant updated")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Could not update variant")}
    end
  end

  defp valid_supplier?(_suppliers, nil), do: true
  defp valid_supplier?(suppliers, supplier_id), do: Enum.any?(suppliers, &(&1.id == supplier_id))

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-[1600px] mx-auto px-4 sm:px-6 space-y-6">
      <.admin_page_header title="Inventory" subtitle="Monitor stock levels and manage inventory" />

      <%!-- Stat Cards --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <.stat_card label="Total SKUs" value={Integer.to_string(@stats.total)} icon_bg="bg-slate-100">
          <:icon>
            <svg
              class="w-5 h-5 text-slate-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M20.25 7.5l-.625 10.632a2.25 2.25 0 01-2.247 2.118H6.622a2.25 2.25 0 01-2.247-2.118L3.75 7.5M10 11.25h4M3.375 7.5h17.25c.621 0 1.125-.504 1.125-1.125v-1.5c0-.621-.504-1.125-1.125-1.125H3.375c-.621 0-1.125.504-1.125 1.125v1.5c0 .621.504 1.125 1.125 1.125z"
              />
            </svg>
          </:icon>
        </.stat_card>
        <.stat_card
          label="In Stock"
          value={Integer.to_string(@stats.in_stock)}
          icon_bg="bg-emerald-50"
        >
          <:icon>
            <svg
              class="w-5 h-5 text-emerald-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </:icon>
        </.stat_card>
        <.stat_card
          label="Low Stock"
          value={Integer.to_string(@stats.low_stock)}
          icon_bg="bg-amber-50"
        >
          <:icon>
            <svg
              class="w-5 h-5 text-amber-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
              />
            </svg>
          </:icon>
        </.stat_card>
        <.stat_card
          label="Out of Stock"
          value={Integer.to_string(@stats.out_of_stock)}
          icon_bg="bg-red-50"
        >
          <:icon>
            <svg
              class="w-5 h-5 text-red-600"
              fill="none"
              stroke="currentColor"
              stroke-width="1.5"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
              />
            </svg>
          </:icon>
        </.stat_card>
      </div>

      <%!-- Locations Manager --%>
      <.locations_card
        :if={@store_id}
        locations={@locations}
        totals={@location_totals}
        renaming_id={@renaming_location_id}
        show_form={@show_location_form}
        location_form={@location_form}
        rename_location_form={@rename_location_form}
      />

      <%!-- Filter Bar --%>
      <div class="flex flex-col sm:flex-row items-start sm:items-center gap-3">
        <.filter_tabs
          id="inventory-filter-tabs"
          current={@status_filter}
          tabs={[
            %{key: :all, label: "All", count: @stats.total},
            %{key: :in_stock, label: "In Stock", count: @stats.in_stock},
            %{key: :low_stock, label: "Low Stock", count: @stats.low_stock},
            %{key: :out_of_stock, label: "Out of Stock", count: @stats.out_of_stock}
          ]}
        />
        <div class="flex-1 w-full sm:w-auto">
          <.form
            for={@search_form}
            id="inventory-search-form"
            phx-change="search_inventory"
            class="relative"
          >
            <svg
              class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                d="M21 21l-5.197-5.197m0 0A7.5 7.5 0 105.196 5.196a7.5 7.5 0 0010.607 10.607z"
              />
            </svg>
            <.input
              field={@search_form[:query]}
              type="text"
              placeholder="Search by product or SKU..."
              phx-debounce="300"
              class="w-full pl-9 pr-4 py-2 text-sm border border-slate-200 rounded-control bg-white focus:outline-none focus:ring-2 focus:ring-slate-900/10 focus:border-slate-300"
            />
          </.form>
        </div>
      </div>

      <%!-- Stock Table --%>
      <%= if @variants == [] do %>
        <.empty_state
          icon="hero-archive-box"
          title="No variants found"
          description={
            if @status_filter != :all or @search_query != "",
              do: "Try adjusting your filters or search query",
              else: "Add products with variants to start tracking inventory"
          }
        />
      <% else %>
        <%!-- Desktop Table --%>
        <.admin_card padding={:none} class="hidden md:block overflow-hidden">
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-slate-200 bg-slate-50/50">
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Product
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Variant (SKU)
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Current Stock
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Status
                  </th>
                  <th class="px-4 py-3.5 text-left text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr
                  :for={variant <- @variants}
                  class="hover:bg-slate-50 transition-colors"
                >
                  <td class="px-4 py-3.5">
                    <div class="flex items-center gap-3">
                      <.product_thumb
                        url={variant_image_url(variant)}
                        alt={product_title(variant)}
                        class="w-9 h-9"
                      />
                      <div class="min-w-0">
                        <span class="text-slate-700 font-medium">{product_title(variant)}</span>
                        <span
                          :if={variant.supplier_id}
                          class="ml-2 inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-violet-50 text-violet-700"
                          title={dropship_label(variant)}
                        >
                          Dropshipped
                        </span>
                      </div>
                    </div>
                  </td>
                  <td class="px-4 py-3.5 font-mono text-xs text-slate-500">
                    {variant.sku || "--"}
                  </td>
                  <td class="px-4 py-3.5">
                    <%= if @editing_variant_id == variant.id do %>
                      <.form
                        for={@stock_form}
                        id="stock-edit-form"
                        phx-submit="save_stock"
                        phx-change="edit_location_changed"
                        phx-value-id={variant.id}
                        class="flex items-center gap-2"
                      >
                        <.input field={@stock_form[:variant_id]} type="hidden" />
                        <.input
                          field={@stock_form[:location_id]}
                          type="select"
                          options={Enum.map(Enum.filter(@locations, & &1.active), &{&1.name, &1.id})}
                          class="px-2 py-1 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                        />
                        <.input
                          field={@stock_form[:stock]}
                          type="number"
                          min="0"
                          class="w-20 px-2 py-1 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-slate-900/10"
                          autofocus
                        />
                        <button
                          type="submit"
                          class="text-primary hover:text-primary-hover"
                          title="Save"
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
                              d="M4.5 12.75l6 6 9-13.5"
                            />
                          </svg>
                        </button>
                        <button
                          type="button"
                          phx-click="cancel_edit"
                          class="text-slate-400 hover:text-slate-600"
                          title="Cancel"
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
                        </button>
                      </.form>
                    <% else %>
                      <div class="flex items-center gap-2.5">
                        <button
                          phx-click="start_edit"
                          phx-value-id={variant.id}
                          class="font-mono text-sm font-semibold text-slate-800 hover:text-slate-600 cursor-pointer"
                          title="Click to edit stock"
                        >
                          {variant.stock_quantity}
                        </button>
                        <.stock_meter quantity={variant.stock_quantity} />
                      </div>
                      <.location_breakdown
                        :if={@multi_location?}
                        entries={breakdown_entries(variant, @levels_by_variant, @locations)}
                      />
                      <p
                        :if={reserved_by_susu(@susu_reserved_by_variant, variant.id) > 0}
                        class="text-xs text-amber-600 mt-0.5"
                      >
                        Reserved by susu: {reserved_by_susu(@susu_reserved_by_variant, variant.id)}
                      </p>
                    <% end %>
                  </td>
                  <td class="px-4 py-3.5">
                    <.stock_status_badge quantity={variant.stock_quantity} />
                  </td>
                  <td class="px-4 py-3.5">
                    <div class="flex items-center gap-1">
                      <button
                        phx-click="adjust_stock"
                        phx-value-id={variant.id}
                        phx-value-delta="-1"
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors disabled:opacity-50"
                        disabled={variant.stock_quantity == 0}
                        title="Decrease by 1"
                      >
                        <svg
                          class="w-3.5 h-3.5"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          viewBox="0 0 24 24"
                        >
                          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12h-15" />
                        </svg>
                      </button>
                      <button
                        phx-click="adjust_stock"
                        phx-value-id={variant.id}
                        phx-value-delta="1"
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors"
                        title="Increase by 1"
                      >
                        <svg
                          class="w-3.5 h-3.5"
                          fill="none"
                          stroke="currentColor"
                          stroke-width="2"
                          viewBox="0 0 24 24"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            d="M12 4.5v15m7.5-7.5h-15"
                          />
                        </svg>
                      </button>
                      <button
                        :if={@multi_location?}
                        phx-click={
                          JS.push("open_transfer", value: %{id: variant.id})
                          |> show_modal("transfer-modal")
                        }
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors"
                        title="Transfer between locations"
                      >
                        <.icon name="hero-arrows-right-left" class="w-3.5 h-3.5" />
                      </button>
                      <button
                        phx-click={
                          JS.push("edit_dropship", value: %{id: variant.id})
                          |> show_modal("dropship-modal")
                        }
                        class="inline-flex items-center justify-center w-7 h-7 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100 hover:text-slate-700 transition-colors"
                        title="Edit supplier / cost / availability"
                      >
                        <.icon name="hero-truck" class="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </.admin_card>

        <%!-- Mobile Cards --%>
        <div class="md:hidden space-y-3">
          <.admin_card :for={variant <- @variants} padding={:none} class="p-4">
            <div class="flex items-start justify-between gap-3 mb-3">
              <div class="flex items-center gap-3 min-w-0">
                <.product_thumb
                  url={variant_image_url(variant)}
                  alt={product_title(variant)}
                  class="w-10 h-10"
                />
                <div class="min-w-0">
                  <p class="text-sm font-medium text-slate-800">
                    {product_title(variant)}
                    <span
                      :if={variant.supplier_id}
                      class="ml-1 inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold bg-violet-50 text-violet-700"
                    >
                      Dropshipped
                    </span>
                  </p>
                  <p class="font-mono text-xs text-slate-400 mt-0.5">{variant.sku || "--"}</p>
                </div>
              </div>
              <.stock_status_badge quantity={variant.stock_quantity} />
            </div>
            <div class="flex items-center justify-between">
              <div>
                <div class="flex items-center gap-2 text-sm text-slate-600">
                  <span class="text-slate-400">Stock:</span>
                  <.stock_meter quantity={variant.stock_quantity} />
                </div>
                <.location_breakdown
                  :if={@multi_location?}
                  entries={breakdown_entries(variant, @levels_by_variant, @locations)}
                />
                <p
                  :if={reserved_by_susu(@susu_reserved_by_variant, variant.id) > 0}
                  class="text-xs text-amber-600 mt-0.5"
                >
                  Reserved by susu: {reserved_by_susu(@susu_reserved_by_variant, variant.id)}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <button
                  phx-click="adjust_stock"
                  phx-value-id={variant.id}
                  phx-value-delta="-1"
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
                  disabled={variant.stock_quantity == 0}
                >
                  <svg
                    class="w-4 h-4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    viewBox="0 0 24 24"
                  >
                    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 12h-15" />
                  </svg>
                </button>
                <button
                  phx-click="adjust_stock"
                  phx-value-id={variant.id}
                  phx-value-delta="1"
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
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
                      d="M12 4.5v15m7.5-7.5h-15"
                    />
                  </svg>
                </button>
                <button
                  :if={@multi_location?}
                  phx-click={
                    JS.push("open_transfer", value: %{id: variant.id})
                    |> show_modal("transfer-modal")
                  }
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
                  title="Transfer between locations"
                >
                  <.icon name="hero-arrows-right-left" class="w-4 h-4" />
                </button>
                <button
                  phx-click={
                    JS.push("edit_dropship", value: %{id: variant.id})
                    |> show_modal("dropship-modal")
                  }
                  class="inline-flex items-center justify-center w-8 h-8 rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-100"
                  title="Edit supplier / cost / availability"
                >
                  <.icon name="hero-truck" class="w-4 h-4" />
                </button>
              </div>
            </div>
          </.admin_card>
        </div>
      <% end %>

      <%!-- Dropship editor modal --%>
      <.modal id="dropship-modal" title="Supplier & Dropshipping" size={:md}>
        <.form
          :if={@dropship_variant}
          for={@dropship_form}
          id="dropship-form"
          phx-submit="save_dropship"
          class="space-y-4"
        >
          <div>
            <.input
              field={@dropship_form[:supplier_id]}
              type="select"
              label="Supplier"
              prompt="— Own stock —"
              options={Enum.map(@suppliers, &{&1.name, &1.id})}
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
            <p class="text-xs text-slate-400 mt-1">
              Assigning a supplier marks this variant as dropshipped (inventory no longer tracked).
            </p>
          </div>
          <div>
            <.input
              field={@dropship_form[:cost_price]}
              type="number"
              label="Cost Price (GH₵)"
              step="0.01"
              min="0"
              placeholder="0.00"
              class="w-full px-3 py-2.5 text-sm rounded-lg border border-slate-300 focus:ring-2 focus:ring-emerald-500 focus:border-emerald-500"
            />
          </div>
          <.input
            field={@dropship_form[:available]}
            type="checkbox"
            label="Available for sale"
            class="rounded border-slate-300 text-primary focus:ring-emerald-500"
          />
          <div class="flex items-center justify-end gap-3 pt-2">
            <.admin_button variant={:secondary} phx-click={hide_modal("dropship-modal")}>
              Cancel
            </.admin_button>
            <.admin_button type="submit" phx-click={hide_modal("dropship-modal")}>
              Save
            </.admin_button>
          </div>
        </.form>
      </.modal>

      <%!-- Transfer stock modal --%>
      <.transfer_modal
        variant={@transfer_variant}
        locations={@locations}
        form={@transfer_form}
      />
    </div>
    """
  end

  defp dropship_label(%{supplier: %{name: name}}) when is_binary(name), do: "Supplier: #{name}"
  defp dropship_label(_), do: "Dropshipped"

  # ── Data Loading ──

  defp reload_inventory(socket) do
    socket
    |> load_locations()
    |> load_variants()
    |> load_levels()
    |> load_susu_reserved()
  end

  # Reserved-by-susu is a pure visibility aggregate (TC-3 Task 9) — the
  # underlying stock was already decremented from available stock at
  # activation (see `Emakola.Orders.SusuStock`'s moduledoc), so this loads
  # nothing that changes `variant.stock_quantity` — it just tells the
  # merchant how much of it is tied up in in-flight susu plans.
  defp load_susu_reserved(socket) do
    case socket.assigns.store_id do
      nil ->
        assign(socket, susu_reserved_by_variant: %{})

      store_id ->
        assign(socket,
          susu_reserved_by_variant:
            Emakola.Orders.SusuStock.reserved_quantities_by_variant(store_id)
        )
    end
  end

  defp load_locations(socket) do
    case socket.assigns.store_id do
      nil ->
        assign(socket, locations: [], multi_location?: false)

      store_id ->
        Emakola.Inventory.ensure_default_location!(store_id)

        locations =
          case Emakola.Inventory.list_locations(actor(socket), store_id) do
            {:ok, locations} -> locations
            _ -> []
          end

        assign(socket,
          locations: locations,
          multi_location?: Enum.count(locations, & &1.active) > 1
        )
    end
  end

  defp load_variants(socket) do
    store_id = socket.assigns.store_id
    all_variants = fetch_variants(store_id)
    stats = compute_stats(store_id)

    socket
    |> assign(all_variants: all_variants, stats: stats)
    |> apply_filters()
  end

  defp load_levels(socket) do
    %{store_id: store_id, locations: locations, all_variants: all_variants} = socket.assigns

    levels_by_variant =
      with store_id when not is_nil(store_id) <- store_id,
           {:ok, levels_map} <- Emakola.Inventory.levels_by_variant(actor(socket), store_id) do
        levels_map
      else
        _ -> %{}
      end

    assign(socket,
      levels_by_variant: levels_by_variant,
      location_totals: compute_location_totals(locations, all_variants, levels_by_variant)
    )
  end

  # Per-location totals from the level rows, plus the stock of variants
  # that have never been seeded with levels — that stock implicitly lives
  # at the default location (the domain seeds it from the total on first
  # write).
  defp compute_location_totals(locations, all_variants, levels_by_variant) do
    base = Map.new(locations, &{&1.id, 0})

    seeded =
      for {_variant_id, levels} <- levels_by_variant, level <- levels, reduce: base do
        acc -> Map.update(acc, level.location_id, level.quantity, &(&1 + level.quantity))
      end

    unseeded_total =
      all_variants
      |> Enum.filter(&(&1.track_inventory and not Map.has_key?(levels_by_variant, &1.id)))
      |> Enum.map(&max(&1.stock_quantity, 0))
      |> Enum.sum()

    case Enum.find(locations, & &1.default) do
      nil -> seeded
      default -> Map.update(seeded, default.id, unseeded_total, &(&1 + unseeded_total))
    end
  end

  defp apply_filters(socket) do
    %{all_variants: all_variants, status_filter: status, search_query: query} = socket.assigns

    filtered =
      all_variants
      |> filter_by_status(status)
      |> filter_by_search(query)

    assign(socket, variants: filtered)
  end

  defp fetch_variants(nil), do: []

  defp fetch_variants(store_id) do
    try do
      Emakola.Catalog.list_variants_admin!(store_id, query: [limit: 200], authorize?: false)
    rescue
      exception ->
        Logger.error(
          "[inventory_live] fetch_variants loading variants raised: #{Exception.message(exception)}"
        )

        []
    end
  end

  defp filter_by_status(variants, :all), do: variants

  defp filter_by_status(variants, :in_stock),
    do: Enum.filter(variants, &(&1.stock_quantity >= 10))

  defp filter_by_status(variants, :low_stock),
    do: Enum.filter(variants, &(&1.stock_quantity >= 1 and &1.stock_quantity < 10))

  defp filter_by_status(variants, :out_of_stock),
    do: Enum.filter(variants, &(&1.stock_quantity == 0))

  defp filter_by_search(variants, ""), do: variants
  defp filter_by_search(variants, nil), do: variants

  defp filter_by_search(variants, query) do
    downcased = String.downcase(query)

    Enum.filter(variants, fn variant ->
      product_name = product_title(variant) |> String.downcase()
      sku = (variant.sku || "") |> String.downcase()
      String.contains?(product_name, downcased) or String.contains?(sku, downcased)
    end)
  end

  defp compute_stats(nil) do
    %{total: 0, in_stock: 0, low_stock: 0, out_of_stock: 0}
  end

  defp compute_stats(store_id) do
    %{
      total: count_stock(store_id, nil, nil),
      in_stock: count_stock(store_id, 10, nil),
      low_stock: count_stock(store_id, 1, 9),
      out_of_stock: count_stock(store_id, nil, 0)
    }
  end

  defp count_stock(store_id, min, max) do
    Emakola.Catalog.Variant
    |> Ash.Query.for_read(:by_stock_range, %{store_id: store_id, min: min, max: max})
    |> Ash.count!(authorize?: false)
  end

  # ── Helpers ──

  defp actor(socket), do: socket.assigns[:current_merchant]

  defp find_location(locations, id), do: Enum.find(locations, &(&1.id == id))

  # The variant's current stock at a location. A variant with no level
  # rows has never been written through the domain — its whole total
  # implicitly sits at the default location (levels seed lazily,
  # default-first, so a missing default row means no rows at all).
  defp location_quantity(socket, variant, location_id) do
    levels = Map.get(socket.assigns.levels_by_variant, variant.id, [])
    default = Enum.find(socket.assigns.locations, & &1.default)

    case Enum.find(levels, &(&1.location_id == location_id)) do
      %{quantity: quantity} ->
        quantity

      nil ->
        if (levels == [] and default) && default.id == location_id,
          do: max(variant.stock_quantity, 0),
          else: 0
    end
  end

  # Entries for the per-location breakdown line: {name, qty} for active
  # locations holding stock. Unseeded tracked variants show their total
  # at the default location.
  defp breakdown_entries(%{track_inventory: false}, _levels_by_variant, _locations), do: []

  defp breakdown_entries(variant, levels_by_variant, locations) do
    case Map.get(levels_by_variant, variant.id) do
      nil ->
        default = Enum.find(locations, & &1.default)

        if default && variant.stock_quantity > 0,
          do: [{default.name, variant.stock_quantity}],
          else: []

      levels ->
        for level <- levels, level.location.active, level.quantity > 0 do
          {level.location.name, level.quantity}
        end
    end
  end

  defp parse_positive_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {quantity, _} when quantity > 0 -> quantity
      _ -> nil
    end
  end

  defp parse_positive_int(_), do: nil

  defp load_suppliers(socket) do
    case socket.assigns.store_id do
      nil ->
        assign(socket, suppliers: [])

      store_id ->
        suppliers =
          Emakola.Suppliers.list_active_suppliers_by_store!(store_id, authorize?: false)

        assign(socket, suppliers: suppliers)
    end
  end

  defp get_store_id(socket) do
    case socket.assigns[:current_store] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp parse_cost(value) when is_binary(value) do
    case value |> String.trim() |> Decimal.parse() do
      {%Decimal{} = amount, ""} ->
        amount
        |> Decimal.mult(100)
        |> Decimal.round(0, :down)
        |> Decimal.to_integer()

      _ ->
        nil
    end
  end

  defp parse_cost(_), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp blank_to_nil(_), do: nil

  defp reserved_by_susu(map, variant_id), do: Map.get(map, variant_id, 0)

  defp cost_in_cedis(nil), do: ""

  defp cost_in_cedis(pesewas) when is_integer(pesewas),
    do: :erlang.float_to_binary(pesewas / 100, decimals: 2)

  defp product_title(%{product: %{title: title}}) when is_binary(title), do: title
  defp product_title(_), do: "Unknown Product"

  defp variant_image_url(%{product: %{images: [%{thumbnail_url: url} | _]}})
       when is_binary(url) and url != "",
       do: url

  defp variant_image_url(%{product: %{images: [%{url: url} | _]}})
       when is_binary(url) and url != "",
       do: url

  defp variant_image_url(_), do: nil

  defp find_variant(variants, id) do
    Enum.find(variants, &(&1.id == id))
  end
end
